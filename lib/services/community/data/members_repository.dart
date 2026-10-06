import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/app_user.dart';
import '../../../platform/session.dart';
import 'community_models.dart';
import 'fake_chat_repository.dart';
import 'fake_feed_repository.dart';
import 'supabase_community_support.dart';

/// Members as other members see them, and what happened to the viewer's
/// posts and messages. Failures surface as [CommunityException].
abstract class CommunityMembersRepository {
  /// A member's public profile; `null` when the account is gone.
  Future<MemberProfile?> fetchMember(String memberId);

  /// Changes the viewer's public line and city.
  Future<MemberProfile> updateMyProfile({
    required AppUser viewer,
    required String bio,
    required String city,
  });

  /// Comments on the viewer's posts, likes of them and answers to the
  /// viewer's chat messages, newest first.
  Future<List<ActivityItem>> fetchActivity({required AppUser viewer});
}

/// Limits the database checks.
abstract final class ProfileLimits {
  static const bio = 160;
  static const city = 40;
}

/// In-memory members for development and tests: sample profiles, and the
/// viewer's activity read from the fake feed and chat when given.
class FakeCommunityMembersRepository implements CommunityMembersRepository {
  FakeCommunityMembersRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    this.feed,
    this.chat,
  }) : _now = now ?? DateTime.now {
    final joined = _now().subtract(const Duration(days: 400));
    for (final (id, name, bio, city) in _sample) {
      _profiles[id] = MemberProfile(
        id: id,
        name: name,
        bio: bio,
        city: city,
        memberSince: joined,
      );
    }
  }

  final Duration latency;
  final DateTime Function() _now;
  final FakeFeedRepository? feed;
  final FakeChatRepository? chat;

  /// While true every call fails, to exercise error states.
  bool failing = false;

  final _profiles = <String, MemberProfile>{};

  static const _sample = [
    ('demo', 'Alex', 'Kelly and Soya keep me busy.', 'Tel Aviv'),
    ('u-maya', 'Maya', 'Biscuit, four months of chaos.', 'Haifa'),
    ('u-sam', 'Sam', 'Pepper loves the beach.', 'Herzliya'),
    ('u-noa', 'Noa', 'Milo and Shoko, a dog and a cat.', 'Jerusalem'),
    ('u-jonas', 'Jonas', 'Luna, rainy-day puzzles fan.', ''),
    ('u-priya', 'Priya', '', 'Ramat Gan'),
    ('u-dana', 'Dana', 'Two cats, one sofa.', 'Beersheba'),
    ('u-omer', 'Omer', '', ''),
  ];

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failing) {
      throw const CommunityException(CommunityFailure.unreachable);
    }
  }

  @override
  Future<MemberProfile?> fetchMember(String memberId) async {
    await _wait();
    final profile = _profiles[memberId];
    if (profile == null) return null;
    final posts = feed == null
        ? 0
        : (await feed!.fetchPosts(
            viewer: AppUser(id: memberId, email: '', displayName: ''),
            query: FeedQuery(authorId: memberId),
            limit: 1000,
          )).length;
    return MemberProfile(
      id: profile.id,
      name: profile.name,
      bio: profile.bio,
      city: profile.city,
      memberSince: profile.memberSince,
      postCount: posts,
    );
  }

  @override
  Future<MemberProfile> updateMyProfile({
    required AppUser viewer,
    required String bio,
    required String city,
  }) async {
    await _wait();
    final old = _profiles[viewer.id];
    final profile = MemberProfile(
      id: viewer.id,
      name: old?.name ?? storedAuthorName(viewer.displayName),
      bio: bio.trim(),
      city: city.trim(),
      memberSince: old?.memberSince ?? _now(),
      postCount: old?.postCount ?? 0,
    );
    _profiles[viewer.id] = profile;
    return profile;
  }

  @override
  Future<List<ActivityItem>> fetchActivity({required AppUser viewer}) async {
    await _wait();
    return [...?feed?.activityFor(viewer.id), ...?chat?.repliesTo(viewer.id)]
      ..sort((a, b) => b.at.compareTo(a.at));
  }
}

/// [CommunityMembersRepository] backed by Supabase (`community_members`,
/// `profiles` and `community_activity` in `0022_community_feed_profiles.sql`).
class SupabaseCommunityMembersRepository implements CommunityMembersRepository {
  SupabaseCommunityMembersRepository(this._backend);

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  @override
  Future<MemberProfile?> fetchMember(String memberId) =>
      guardCommunity(() async {
        final row = await _client
            .from('community_members')
            .select()
            .eq('id', memberId)
            .maybeSingle();
        return row == null ? null : _toProfile(row);
      });

  @override
  Future<MemberProfile> updateMyProfile({
    required AppUser viewer,
    required String bio,
    required String city,
  }) => guardCommunity(() async {
    await _client
        .from('profiles')
        .update({'bio': bio.trim(), 'city': city.trim()})
        .eq('id', viewer.id);
    final row = await _client
        .from('community_members')
        .select()
        .eq('id', viewer.id)
        .single();
    return _toProfile(row);
  });

  @override
  Future<List<ActivityItem>> fetchActivity({required AppUser viewer}) =>
      guardCommunity(() async {
        final rows = await _client
            .from('community_activity')
            .select()
            .order('created_at', ascending: false)
            .limit(50);
        return [
          for (final row in rows)
            ActivityItem(
              kind: ActivityKind.values.byName(row['kind'] as String),
              id: row['id'] as String,
              targetId: row['target_id'] as String,
              actorId: row['actor_id'] as String,
              actorName: storedAuthorName(row['actor_name'] as String?),
              preview: row['preview'] as String? ?? '',
              at: parseTimestamp(row['created_at']),
            ),
        ];
      });

  MemberProfile _toProfile(Map<String, dynamic> row) => MemberProfile(
    id: row['id'] as String,
    name: storedAuthorName(row['display_name'] as String?),
    bio: row['bio'] as String? ?? '',
    city: row['city'] as String? ?? '',
    memberSince: row['member_since'] == null
        ? null
        : parseTimestamp(row['member_since']),
    postCount: (row['post_count'] as num?)?.toInt() ?? 0,
  );
}
