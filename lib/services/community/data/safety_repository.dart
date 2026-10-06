import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/app_user.dart';
import '../../../platform/session.dart';
import 'community_models.dart';
import 'supabase_community_support.dart';

/// Keeping the community safe: blocking members, reporting comments, and
/// the moderators' review of what members reported.
///
/// Blocking hides a member's posts, comments and messages from the
/// blocker. On Supabase row level security does it everywhere; the screens
/// also filter by [fetchBlocked], so a block takes effect at once.
/// Failures surface as [CommunityException].
abstract class CommunitySafetyRepository {
  /// The members [viewer] blocked, most recent first.
  Future<List<BlockedMember>> fetchBlocked({required AppUser viewer});

  Future<void> block({required AppUser viewer, required BlockedMember member});

  Future<void> unblock({required AppUser viewer, required String memberId});

  /// Records a report and hides the comment from [viewer].
  Future<void> reportComment({
    required AppUser viewer,
    required String commentId,
    required ReportReason reason,
  });

  /// What members reported since the last decision on it, newest report
  /// first. Moderators only ([CommunityFailure.notModerator] otherwise).
  Future<List<ModerationItem>> fetchModerationQueue();

  /// Keeps (and shows again) or removes a reported item. Moderators only.
  Future<void> moderate({
    required ModerationItem item,
    required ModerationDecision decision,
  });
}

/// In-memory [CommunitySafetyRepository] for development and tests, with
/// two reported items waiting for review.
class FakeCommunitySafetyRepository implements CommunitySafetyRepository {
  FakeCommunitySafetyRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    bool seeded = true,
  }) : _now = now ?? DateTime.now {
    if (seeded) _seed();
  }

  final Duration latency;
  final DateTime Function() _now;

  /// While true every call fails, to exercise error states.
  bool failing = false;

  final _blocked = <String, List<BlockedMember>>{};

  /// Every comment report filed, for tests.
  final commentReports =
      <({String commentId, String reporterId, ReportReason reason})>[];

  /// The review queue, and the decisions taken, for tests.
  final queue = <ModerationItem>[];
  final decisions = <(String id, ModerationDecision decision)>[];

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failing) {
      throw const CommunityException(CommunityFailure.unreachable);
    }
  }

  @override
  Future<List<BlockedMember>> fetchBlocked({required AppUser viewer}) async {
    await _wait();
    return List.unmodifiable(_blocked[viewer.id] ?? const <BlockedMember>[]);
  }

  @override
  Future<void> block({
    required AppUser viewer,
    required BlockedMember member,
  }) async {
    await _wait();
    if (member.id == viewer.id) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    final list = _blocked.putIfAbsent(viewer.id, () => []);
    list.removeWhere((m) => m.id == member.id);
    list.insert(0, member);
  }

  @override
  Future<void> unblock({
    required AppUser viewer,
    required String memberId,
  }) async {
    await _wait();
    _blocked[viewer.id]?.removeWhere((m) => m.id == memberId);
  }

  @override
  Future<void> reportComment({
    required AppUser viewer,
    required String commentId,
    required ReportReason reason,
  }) async {
    await _wait();
    commentReports.add((
      commentId: commentId,
      reporterId: viewer.id,
      reason: reason,
    ));
  }

  @override
  Future<List<ModerationItem>> fetchModerationQueue() async {
    await _wait();
    return List.unmodifiable(queue);
  }

  @override
  Future<void> moderate({
    required ModerationItem item,
    required ModerationDecision decision,
  }) async {
    await _wait();
    queue.removeWhere((i) => i.id == item.id && i.kind == item.kind);
    decisions.add((item.id, decision));
  }

  void _seed() {
    final now = _now();
    queue.addAll([
      ModerationItem(
        kind: ModerationKind.message,
        id: 'mod-1',
        authorId: 'u-spam',
        authorName: 'Best Deals',
        text: 'Cheap puppies for sale, message me now!!!',
        createdAt: now.subtract(const Duration(hours: 2)),
        reportCount: 3,
        reasons: const [ReportReason.spam],
        hidden: true,
        context: 'general',
      ),
      ModerationItem(
        kind: ModerationKind.comment,
        id: 'mod-2',
        authorId: 'u-sam',
        authorName: 'Sam',
        text: 'That is a silly question, just google it.',
        createdAt: now.subtract(const Duration(hours: 5)),
        reportCount: 1,
        reasons: const [ReportReason.abusive],
        hidden: false,
        context: 'p1',
      ),
    ]);
  }
}

/// [CommunitySafetyRepository] backed by Supabase (`user_blocks`,
/// `community_comment_reports`, `community_moderation_queue()` and
/// `community_moderate()` in `0021_community_chat_safety.sql`).
class SupabaseCommunitySafetyRepository implements CommunitySafetyRepository {
  SupabaseCommunitySafetyRepository(sb.SupabaseClient client)
    : _backend = client,
      _names = ProfileNames(client) {
    _photos = CommunityPhotos(() => _client);
  }

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  final ProfileNames _names;
  late final CommunityPhotos _photos;

  @override
  Future<List<BlockedMember>> fetchBlocked({required AppUser viewer}) =>
      guardCommunity(() async {
        final rows = await _client
            .from('user_blocks')
            .select('blocked_id')
            .eq('blocker_id', viewer.id)
            .order('created_at', ascending: false);
        final ids = [for (final row in rows) row['blocked_id'] as String];
        final names = await _names.resolve(ids);
        return [
          for (final id in ids) BlockedMember(id: id, name: names[id] ?? ''),
        ];
      });

  @override
  Future<void> block({
    required AppUser viewer,
    required BlockedMember member,
  }) => guardCommunity(() async {
    await _client
        .from('user_blocks')
        .upsert(
          {'blocker_id': viewer.id, 'blocked_id': member.id},
          onConflict: 'blocker_id,blocked_id',
          ignoreDuplicates: true,
        );
  });

  @override
  Future<void> unblock({required AppUser viewer, required String memberId}) =>
      guardCommunity(() async {
        await _client
            .from('user_blocks')
            .delete()
            .eq('blocker_id', viewer.id)
            .eq('blocked_id', memberId);
      });

  @override
  Future<void> reportComment({
    required AppUser viewer,
    required String commentId,
    required ReportReason reason,
  }) => guardCommunity(() async {
    await _client
        .from('community_comment_reports')
        .upsert(
          {
            'comment_id': commentId,
            'reporter_id': viewer.id,
            'reason': reason.name,
          },
          onConflict: 'comment_id,reporter_id',
          ignoreDuplicates: true,
        );
  });

  @override
  Future<List<ModerationItem>> fetchModerationQueue() =>
      _moderatorCall(() async {
        final rows =
            (await _client.rpc('community_moderation_queue') as List?) ??
            const [];
        final items = [
          for (final row in rows) Map<String, dynamic>.from(row as Map),
        ];
        final links = await _photos.links([
          for (final row in items)
            if (row['photo_path'] case final String path) path,
        ]);
        return [
          for (final row in items)
            ModerationItem(
              kind: ModerationKind.values.byName(row['kind'] as String),
              id: row['id'] as String,
              authorId: row['author_id'] as String,
              authorName: storedAuthorName(row['author_name'] as String?),
              text: row['body'] as String? ?? '',
              photo: switch (row['photo_path']) {
                final String path when links[path] != null => RemotePostPhoto(
                  url: links[path]!,
                  cacheKey: path,
                ),
                _ => null,
              },
              createdAt: parseTimestamp(row['created_at']),
              reportCount: (row['report_count'] as num?)?.toInt() ?? 0,
              reasons: [
                for (final reason in (row['reasons'] as List?) ?? const [])
                  ?ReportReason.values.asNameMap()[reason],
              ],
              hidden: row['hidden'] as bool? ?? false,
              context: row['context'] as String?,
            ),
        ];
      });

  @override
  Future<void> moderate({
    required ModerationItem item,
    required ModerationDecision decision,
  }) => _moderatorCall(() async {
    await _client.rpc(
      'community_moderate',
      params: {
        'p_kind': item.kind.name,
        'p_id': item.id,
        'p_action': decision.name,
      },
    );
  });

  /// A moderator call whose refusal says "moderators only".
  Future<T> _moderatorCall<T>(Future<T> Function() action) async {
    try {
      return await guardCommunity(action);
    } on CommunityException catch (e) {
      if (e.failure == CommunityFailure.notAllowed) {
        throw CommunityException(CommunityFailure.notModerator, e.detail);
      }
      rethrow;
    }
  }
}
