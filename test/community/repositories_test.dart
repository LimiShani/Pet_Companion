import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/features/community/community_words.dart';
import 'package:pet_companion/features/community/data/audience.dart';
import 'package:pet_companion/features/community/data/community_language.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/data/guides/guide_catalog.dart';
import 'package:pet_companion/features/community/data/guides/guides_en.dart';
import 'package:pet_companion/features/community/data/guides/guides_he.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';
import 'package:pet_companion/features/community/data/supabase_community_support.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'guide_fixtures.dart';

const alex = AppUser(id: 'demo', email: 'demo@petcompanion.app', displayName: 'Alex');
const dana = AppUser(id: 'u-dana', email: 'dana@example.com', displayName: 'Dana');

final fixedNow = DateTime(2026, 5, 14, 9, 41);
DateTime clock() => fixedNow;

/// Every word of a guide's text, for checks on the wording.
String wordsOf(GuideText text) => [
      text.title,
      text.summary,
      text.intro,
      for (final s in text.sections) ...[s.heading, ...s.paragraphs, ...s.bullets, ...s.after],
    ].join(' ');

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
      expect(channels.map((c) => c.name), [
        'General',
        'Puppies',
        'Training tips',
        'Senior dogs',
        'Kittens',
        'Litter and cleaning',
        'Cat behaviour and play',
        'Senior cats',
        'Health questions',
      ]);
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

  group('FakeChatRepository rooms by animal', () {
    test('dog rooms, cat rooms and shared rooms', () async {
      final channels = await FakeChatRepository(latency: Duration.zero).fetchChannels();
      List<String> idsFor(CommunityScope scope) => [
            for (final c in channels)
              if (scope.shows(c.audience)) c.id,
          ];

      expect(idsFor(CommunityScope.dogs), ['general', 'puppies', 'training', 'seniors', 'health']);
      expect(idsFor(CommunityScope.cats), ['general', 'kittens', 'cat-litter', 'cat-behaviour', 'senior-cats', 'health']);
      expect(idsFor(CommunityScope.everything), hasLength(9));
    });
  });

  group('audience and scope', () {
    test('a stored audience reads back, unknown kinds only show under Everything', () {
      expect(Audience.fromKey(null), Audience.everyone);
      expect(Audience.fromKey('all'), Audience.everyone);
      expect(Audience.fromKey('dog'), Audience.dogs);
      expect(Audience.fromKey('cat'), Audience.cats);
      expect(Audience.fromKey('rabbit'), Audience.other);

      expect(CommunityScope.dogs.shows(Audience.other), isFalse);
      expect(CommunityScope.cats.shows(Audience.other), isFalse);
      expect(CommunityScope.everything.shows(Audience.other), isTrue);
      expect(CommunityScope.cats.shows(Audience.everyone), isTrue);
      expect(CommunityScope.cats.shows(Audience.dogs), isFalse);
    });

    test('the starting view follows the kind of pet', () {
      expect(CommunityScope.forSpecies(PetSpecies.dog), CommunityScope.dogs);
      expect(CommunityScope.forSpecies(PetSpecies.cat), CommunityScope.cats);
      for (final other in [PetSpecies.bird, PetSpecies.rabbit, PetSpecies.reptile, PetSpecies.other]) {
        expect(CommunityScope.forSpecies(other), CommunityScope.everything, reason: other.name);
      }
    });
  });

  group('content language', () {
    test('a locale code maps to a content language, English by default', () {
      expect(ContentLanguage.fromCode('he'), ContentLanguage.he);
      expect(ContentLanguage.fromCode('iw'), ContentLanguage.he);
      expect(ContentLanguage.fromCode('en'), ContentLanguage.en);
      expect(ContentLanguage.fromCode('fr'), ContentLanguage.en);
      expect(ContentLanguage.fromCode(null), ContentLanguage.en);
      expect(ContentLanguage.he.direction, TextDirection.rtl);
      expect(ContentLanguage.en.direction, TextDirection.ltr);
    });
  });

  group('BundledGuidesRepository', () {
    const repo = BundledGuidesRepository();

    test('has nine dog and nine cat guides across six categories, each well formed', () async {
      final categories = await repo.fetchCategories();
      final guides = await repo.fetchGuides(ContentLanguage.en);

      expect(categories.map((c) => c.name), [
        'Getting started',
        'Home and cleaning',
        'Training and behaviour',
        'Nutrition',
        'Health and grooming',
        'Senior care',
      ]);
      expect(guides, hasLength(18));
      expect(guides.map((g) => g.id).toSet(), hasLength(18));
      expect(guides.where((g) => g.audience == Audience.dogs), hasLength(9));
      expect(guides.where((g) => g.audience == Audience.cats), hasLength(9));
      for (final category in categories) {
        expect(guides.where((g) => g.categoryId == category.id), isNotEmpty, reason: category.name);
      }
      for (final guide in guides) {
        expect(categories.any((c) => c.id == guide.categoryId), isTrue, reason: guide.id);
        expect(guide.sections.length, greaterThanOrEqualTo(3), reason: guide.id);
        expect(guide.readingMinutes, inInclusiveRange(1, 5), reason: guide.id);
        expect(guide.language, ContentLanguage.en, reason: guide.id);
        expect(guide.translated, isTrue, reason: guide.id);
      }
    });

    test('the cat guides are the approved nine', () async {
      final guides = await repo.fetchGuides(ContentLanguage.en);
      expect([for (final g in guides) if (g.audience == Audience.cats) g.title], [
        "Your cat's first week at home",
        'Bringing home a second cat',
        'Setting up the litter box',
        'How many litter boxes do you need?',
        'Keeping litter smell and mess under control',
        'Play and enrichment for indoor cats',
        'When your cat keeps you up at night',
        'Scratching and play biting',
        'Knowing when to call the vet about your cat',
      ]);
    });

    test('search matches every word, anywhere in the guide', () async {
      final guides = await repo.fetchGuides(ContentLanguage.en);
      List<String> search(String q) => [for (final g in guides) if (g.matches(q)) g.id];

      expect(search(''), hasLength(18));
      expect(search('LEAD harness'), contains('loose-lead'));
      expect(search('xylitol chocolate'), ['unsafe-foods']);
      expect(search('litter boxes plus one'), contains('litter-count'));
      expect(search('zzzz'), isEmpty);
    });

    test('every catalog entry has English text, and no text is left without an entry', () {
      final ids = {for (final record in guideRecords) record.id};
      expect(ids, hasLength(guideRecords.length));
      expect(guidesEn.keys.toSet(), ids);
      expect(ids.containsAll(guidesHe.keys), isTrue);
    });

    test('a Hebrew text has the same shape as its English one', () {
      // Holds for every Hebrew guide added later.
      for (final MapEntry(key: id, value: hebrew) in guidesHe.entries) {
        final english = guidesEn[id]!;
        expect(hebrew.sections.length, english.sections.length, reason: id);
        for (var i = 0; i < english.sections.length; i++) {
          expect(hebrew.sections[i].bullets.length, english.sections[i].bullets.length, reason: '$id section $i');
        }
      }
    });

    test('a guide is shown in the asked language, or in English when it has no such text', () async {
      const bilingual = BundledGuidesRepository(
        texts: {
          ContentLanguage.en: guidesEn,
          ContentLanguage.he: {'litter-count': hebrewFixture},
        },
      );

      final hebrew = await bilingual.fetchGuides(ContentLanguage.he);
      expect(hebrew, hasLength(18));
      final translated = hebrew.firstWhere((g) => g.id == 'litter-count');
      expect(translated.title, hebrewFixture.title);
      expect(translated.language, ContentLanguage.he);
      expect(translated.translated, isTrue);
      final fallback = hebrew.firstWhere((g) => g.id == 'litter-setup');
      expect(fallback.title, 'Setting up the litter box');
      expect(fallback.language, ContentLanguage.en);
      expect(fallback.translated, isFalse);

      final english = await bilingual.fetchGuides(ContentLanguage.en);
      expect(english.every((g) => g.translated && g.language == ContentLanguage.en), isTrue);
    });
  });

  group('guide attribution', () {
    final allTexts = {
      for (final MapEntry(:key, :value) in guidesEn.entries) 'en/$key': value,
      for (final MapEntry(:key, :value) in guidesHe.entries) 'he/$key': value,
    };

    test('every guide says who wrote it, in what capacity, and when it last changed', () {
      for (final MapEntry(key: id, value: text) in allTexts.entries) {
        expect(text.author.name.trim(), isNotEmpty, reason: id);
        expect(text.author.role.trim(), isNotEmpty, reason: id);
        expect(text.updatedAt.toDateTime().isBefore(DateTime(2026, 9, 30)), isFalse, reason: id);
      }
    });

    test('the English guides are credited to the team, with the AI assistant and the limits stated', () {
      for (final MapEntry(key: id, value: text) in guidesEn.entries) {
        expect(text.author.name, 'Pet Companion team', reason: id);
        expect(
          text.author.role,
          'App content team, writing with an AI assistant. Not veterinarians or trainers.',
          reason: id,
        );
      }
    });

    test('no bundled guide claims a reviewer or a source today', () {
      // Nobody has reviewed these guides and they cite nothing. If that
      // changes, it changes here on purpose, with a real name and date.
      for (final MapEntry(key: id, value: text) in allTexts.entries) {
        expect(text.review, isNull, reason: id);
        expect(text.currentReview, isNull, reason: id);
        expect(text.sources, isEmpty, reason: id);
      }
    });

    test('changing the text of a guide after its review date removes the review', () {
      const review = GuideReview(
        reviewerName: 'Test Reviewer (fixture)',
        reviewerRole: 'Veterinarian',
        reviewedAt: GuideDate(2026, 10, 5),
      );
      GuideText updated(GuideDate on) => GuideText(
            author: const GuideAuthor(name: 'Fixture', role: 'Fixture'),
            updatedAt: on,
            review: review,
            title: 'Fixture',
            summary: '',
            intro: '',
            sections: const [],
          );

      expect(updated(const GuideDate(2026, 10, 1)).currentReview, same(review)); // reviewed after the last change
      expect(updated(const GuideDate(2026, 10, 5)).currentReview, same(review)); // same day
      expect(updated(const GuideDate(2026, 10, 6)).currentReview, isNull); // changed since: the review lapses
      expect(updated(const GuideDate(2027, 1, 1)).currentReview, isNull);

      // No bundled guide may ship with a review older than its text.
      for (final MapEntry(key: id, value: text) in allTexts.entries) {
        expect(text.currentReview, same(text.review), reason: id);
      }
    });

    test('the guides give no doses and claim no diagnosis', () {
      final dose = RegExp(r'\d+\s?(mg|ml|mcg|milligram|millilitre)', caseSensitive: false);
      for (final MapEntry(key: id, value: text) in guidesEn.entries) {
        expect(wordsOf(text), isNot(contains(dose)), reason: id);
      }
      final vet = wordsOf(guidesEn['cat-call-vet']!);
      expect(vet, contains('only a vet who examines them can'));
      expect(vet, contains('When in doubt, phone your vet practice'));
    });
  });

  group('Supabase error mapping', () {
    // The data layer reports the reason; the words are the screen's, in its
    // own language. Here: the reason, worded in English.
    final words = lookupCommunityL10n(englishLocale);
    final app = lookupAppL10n(englishLocale);
    String message(Object error) => communityFailureText(words, app, communityExceptionFrom(error));

    test('backend errors become friendly messages', () {
      expect(message(const sb.PostgrestException(message: 'new row violates row-level security', code: '42501')),
          'You are not allowed to do that.');
      expect(message(const sb.PostgrestException(message: 'violates check constraint', code: '23514')),
          'That text is empty or too long.');
      expect(message(const sb.PostgrestException(message: 'Could not find the table', code: 'PGRST205')),
          'The community is not set up on the server yet.');
      expect(message(const sb.PostgrestException(message: 'JWT expired', code: 'PGRST303')), 'Please sign in again.');
      expect(message(const sb.StorageException('The object exceeded the maximum allowed size', statusCode: '413')),
          'That photo is too large. Please choose a smaller one.');
      expect(message(const sb.StorageException('mime type image/gif is not supported', statusCode: '415')),
          'Please choose a JPEG, PNG or WebP photo.');
      expect(message(Exception('SocketException: Failed host lookup')), contains('Cannot reach the community'));
    });

    test('community exceptions pass through unchanged', () {
      const original = CommunityException(CommunityFailure.emptyPost);
      expect(communityExceptionFrom(original), same(original));
      expect(message(original), 'Write something before posting.');
    });

    test('a backend error is reported as a reason, and the backend wording is kept for the logs', () {
      final refused = communityExceptionFrom(
        const sb.PostgrestException(message: 'new row violates row-level security', code: '42501'),
      );
      expect(refused.failure, CommunityFailure.notAllowed);
      expect(refused.detail, 'new row violates row-level security');
      expect('$refused', 'CommunityException(notAllowed: new row violates row-level security)');

      expect(communityExceptionFrom(Exception('SocketException')).failure, CommunityFailure.offline);
      expect(
        communityExceptionFrom(const sb.PostgrestException(message: 'something new', code: 'XX000')).failure,
        CommunityFailure.unknown,
      );
      expect(message(const sb.PostgrestException(message: 'something new', code: 'XX000')),
          'Something went wrong. Please try again.');
    });
  });

  group('time formatting', () {
    test('relative time', () {
      final words = lookupCommunityL10n(englishLocale);
      final app = lookupAppL10n(englishLocale);
      String ago(Duration d) => words.relativeTime(app, const AppFormat('en'), fixedNow.subtract(d), fixedNow);

      expect(ago(const Duration(seconds: 20)), 'just now');
      expect(ago(const Duration(minutes: 12)), '12 min ago');
      expect(ago(const Duration(hours: 5)), '5 h ago');
      expect(ago(const Duration(hours: 30)), 'Yesterday');
      expect(ago(const Duration(days: 3)), '3 days ago');
      expect(ago(const Duration(days: 30)), '14.04.26');
    });

    test('chat day labels and clock time', () {
      final app = lookupAppL10n(englishLocale);
      const format = AppFormat('en');
      expect(dayLabel(app, format, DateTime(2026, 5, 14, 0, 5), fixedNow), 'Today');
      expect(dayLabel(app, format, DateTime(2026, 5, 13, 23, 50), fixedNow), 'Yesterday');
      expect(dayLabel(app, format, DateTime(2026, 5, 1, 12), fixedNow), '01.05.26');
      expect(format.time(DateTime(2026, 5, 14, 8, 5)), '08:05');
    });
  });
}
