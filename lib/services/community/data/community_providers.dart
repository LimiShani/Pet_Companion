import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import 'chat_repository.dart';
import 'fake_chat_repository.dart';
import 'fake_feed_repository.dart';
import 'feed_repository.dart';
import 'guides_repository.dart';
import 'members_repository.dart';
import 'safety_repository.dart';
import 'supabase_chat_repository.dart';
import 'supabase_feed_repository.dart';

/// "Now" for everything in the community feature (relative times, new
/// posts in the fakes). Tests override it with a fixed clock.
final communityClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The feed backend: Supabase when the app is built with its
/// configuration, otherwise the in-memory fake with sample posts.
final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseFeedRepository(sb.Supabase.instance.client)
      : FakeFeedRepository(now: ref.watch(communityClockProvider)),
);

/// The chat backend, chosen the same way.
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseChatRepository(sb.Supabase.instance.client)
      : FakeChatRepository(now: ref.watch(communityClockProvider)),
);

/// Blocking, reports on comments and the moderators' review, chosen the
/// same way.
final communitySafetyRepositoryProvider = Provider<CommunitySafetyRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseCommunitySafetyRepository(sb.Supabase.instance.client)
      : FakeCommunitySafetyRepository(now: ref.watch(communityClockProvider)),
);

/// Member profiles and activity, chosen the same way. The fake reads the
/// activity from the fake feed and chat, so what a demo member does shows.
final communityMembersRepositoryProvider = Provider<CommunityMembersRepository>(
  (ref) {
    if (AppConfig.hasSupabase) {
      return SupabaseCommunityMembersRepository(sb.Supabase.instance.client);
    }
    final feed = ref.watch(feedRepositoryProvider);
    final chat = ref.watch(chatRepositoryProvider);
    return FakeCommunityMembersRepository(
      now: ref.watch(communityClockProvider),
      feed: feed is FakeFeedRepository ? feed : null,
      chat: chat is FakeChatRepository ? chat : null,
    );
  },
);

/// Guides are bundled with the app in version 1.
final guidesRepositoryProvider = Provider<GuidesRepository>(
  (ref) => const BundledGuidesRepository(),
);
