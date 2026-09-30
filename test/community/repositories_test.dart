import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/features/community/community_time.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';

const alex = AppUser(id: 'demo', email: 'demo@petcompanion.app', displayName: 'Alex');
const dana = AppUser(id: 'u-dana', email: 'dana@example.com', displayName: 'Dana');

final fixedNow = DateTime(2026, 5, 14, 9, 41);
DateTime clock() => fixedNow;

void main() {
  group('FakeFeedRepository', () {
    late FakeFeedRepository repo;

    setUp(() => repo = FakeFeedRepository(latency: Duration.zero, now: clock));

    test('is seeded newest first, with one post by the demo account', () async {
      final posts = await repo.fetchPosts(viewer: alex);

      expect(posts.length, greaterThanOrEqualTo(5));
      for (var i = 1; i < posts.length; i++) {
        expect(posts[i - 1].createdAt.isAfter(posts[i].createdAt), isTrue);
      }
      expect(posts.first.createdAt, fixedNow.subtract(const Duration(minutes: 12)));
      expect(posts.where((p) => p.authorId == alex.id), hasLength(1));
      expect(posts.any((p) => p.photo is AssetPostPhoto), isTrue);
      expect(posts.any((p) => p.photo == null), isTrue);
    });

    test('creating a post puts it first, with the photo and the pet', () async {
      final created = await repo.createPost(
        author: dana,
        text: '  Hello from Rex  ',
        petName: 'Rex',
        photo: PickedPhoto(bytes: Uint8List.fromList([1, 2, 3]), name: 'rex.jpg'),
      );

      expect(created.text, 'Hello from Rex');
      expect(created.authorName, 'Dana');
      expect(created.petName, 'Rex');
      expect(created.photo, isA<MemoryPostPhoto>());
      expect(created.createdAt, fixedNow);
      expect((await repo.fetchPosts(viewer: alex)).first.id, created.id);
    });

    test('rejects an empty post', () {
      expect(repo.createPost(author: dana, text: '   '), throwsA(isA<CommunityException>()));
    });

    test('a like counts once per user and can be taken back', () async {
      final before = (await repo.fetchPosts(viewer: dana)).first;

      await repo.setLiked(viewer: dana, postId: before.id, liked: true);
      await repo.setLiked(viewer: dana, postId: before.id, liked: true);
      var after = (await repo.fetchPosts(viewer: dana)).first;
      expect(after.likeCount, before.likeCount + 1);
      expect(after.likedByMe, isTrue);
      expect((await repo.fetchPosts(viewer: alex)).first.likedByMe, isFalse);

      await repo.setLiked(viewer: dana, postId: before.id, liked: false);
      after = (await repo.fetchPosts(viewer: dana)).first;
      expect(after.likeCount, before.likeCount);
      expect(after.likedByMe, isFalse);
    });

    test('comments are appended and counted', () async {
      final post = (await repo.fetchPosts(viewer: dana)).first;
      final before = await repo.fetchComments(postId: post.id);

      final comment = await repo.addComment(author: dana, postId: post.id, text: 'Lovely!');

      final after = await repo.fetchComments(postId: post.id);
      expect(after.length, before.length + 1);
      expect(after.last.id, comment.id);
      expect(after.last.authorName, 'Dana');
      expect((await repo.fetchPosts(viewer: dana)).first.commentCount, after.length);
    });

    test('only the author can delete a post', () async {
      final mine = (await repo.fetchPosts(viewer: alex)).firstWhere((p) => p.authorId == alex.id);

      await expectLater(repo.deletePost(viewer: dana, postId: mine.id), throwsA(isA<CommunityException>()));
      await repo.deletePost(viewer: alex, postId: mine.id);

      expect((await repo.fetchPosts(viewer: alex)).any((p) => p.id == mine.id), isFalse);
    });

    test('a report is recorded and hides the post for the reporter only', () async {
      final target = (await repo.fetchPosts(viewer: dana)).first;

      await repo.reportPost(viewer: dana, postId: target.id, reason: ReportReason.spam);
      await repo.reportPost(viewer: dana, postId: target.id, reason: ReportReason.spam);

      expect(repo.reports, [(postId: target.id, reporterId: dana.id, reason: ReportReason.spam)]);
      expect((await repo.fetchPosts(viewer: dana)).any((p) => p.id == target.id), isFalse);
      expect((await repo.fetchPosts(viewer: alex)).any((p) => p.id == target.id), isTrue);
    });

    test('can start empty and can fail', () async {
      final empty = FakeFeedRepository(latency: Duration.zero, seeded: false);
      expect(await empty.fetchPosts(viewer: alex), isEmpty);

      empty.failing = true;
      expect(empty.fetchPosts(viewer: alex), throwsA(isA<CommunityException>()));
    });
  });

  group('FakeChatRepository', () {
    late FakeChatRepository repo;

    setUp(() => repo = FakeChatRepository(latency: Duration.zero, now: clock));

    test('lists the default channels', () async {
      final channels = await repo.fetchChannels();
      expect(channels.map((c) => c.name), ['General', 'Puppies', 'Training tips', 'Senior dogs', 'Health questions']);
    });

    test('the stream emits the history, then every new message', () async {
      final events = <List<ChatMessage>>[];
      final sub = repo.watchMessages('puppies').listen(events.add);
      await pumpEventQueue();

      expect(events, hasLength(1));
      final history = events.single.length;
      expect(history, greaterThan(0));

      await repo.sendMessage(author: alex, channelId: 'puppies', text: ' Hello puppies ');
      repo.receive(channelId: 'puppies', authorId: 'u-maya', authorName: 'Maya', text: 'Hi Alex');
      await repo.sendMessage(author: alex, channelId: 'general', text: 'Other room');
      await pumpEventQueue();

      expect(events, hasLength(3));
      expect(events.last.length, history + 2);
      expect(events.last[history].text, 'Hello puppies');
      expect(events.last[history].authorId, alex.id);
      expect(events.last[history].sentAt, fixedNow);
      expect(events.last.last.authorName, 'Maya');

      await sub.cancel();
    });

    test('a failing backend surfaces as a stream error', () async {
      repo.failing = true;
      await expectLater(repo.watchMessages('general'), emitsError(isA<CommunityException>()));
      expect(repo.fetchChannels(), throwsA(isA<CommunityException>()));
    });
  });

  group('BundledGuidesRepository', () {
    const repo = BundledGuidesRepository();

    test('has nine guides across five categories, each well formed', () async {
      final categories = await repo.fetchCategories();
      final guides = await repo.fetchGuides();

      expect(categories, hasLength(5));
      expect(guides, hasLength(9));
      expect(guides.map((g) => g.id).toSet(), hasLength(9));
      for (final category in categories) {
        expect(guides.where((g) => g.categoryId == category.id), isNotEmpty, reason: category.name);
      }
      for (final guide in guides) {
        expect(categories.any((c) => c.id == guide.categoryId), isTrue, reason: guide.id);
        expect(guide.sections.length, greaterThanOrEqualTo(3), reason: guide.id);
        expect(guide.readingMinutes, inInclusiveRange(1, 5), reason: guide.id);
      }
    });

    test('search matches every word, anywhere in the guide', () async {
      final guides = await repo.fetchGuides();
      List<String> search(String q) => [for (final g in guides) if (g.matches(q)) g.id];

      expect(search(''), hasLength(9));
      expect(search('LEAD harness'), contains('loose-lead'));
      expect(search('xylitol chocolate'), ['unsafe-foods']);
      expect(search('zzzz'), isEmpty);
    });
  });

  group('time formatting', () {
    test('relative time', () {
      String ago(Duration d) => relativeTime(fixedNow.subtract(d), fixedNow);

      expect(ago(const Duration(seconds: 20)), 'just now');
      expect(ago(const Duration(minutes: 12)), '12 min ago');
      expect(ago(const Duration(hours: 5)), '5 h ago');
      expect(ago(const Duration(hours: 30)), 'Yesterday');
      expect(ago(const Duration(days: 3)), '3 days ago');
      expect(ago(const Duration(days: 30)), '14.04.26');
    });

    test('chat day labels and clock time', () {
      expect(dayLabel(DateTime(2026, 5, 14, 0, 5), fixedNow), 'Today');
      expect(dayLabel(DateTime(2026, 5, 13, 23, 50), fixedNow), 'Yesterday');
      expect(dayLabel(DateTime(2026, 5, 1, 12), fixedNow), '01.05.26');
      expect(clockTime(DateTime(2026, 5, 14, 8, 5)), '08:05');
    });
  });
}
