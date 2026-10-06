import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import 'chat_repository.dart';
import 'fake_chat_repository.dart';
import 'fake_feed_repository.dart';
import 'feed_repository.dart';
import 'guides_repository.dart';
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

/// Guides are bundled with the app in version 1.
final guidesRepositoryProvider = Provider<GuidesRepository>(
  (ref) => const BundledGuidesRepository(),
);
