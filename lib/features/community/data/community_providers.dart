import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_repository.dart';
import 'fake_chat_repository.dart';
import 'fake_feed_repository.dart';
import 'feed_repository.dart';
import 'guides_repository.dart';

/// "Now" for everything in the community feature (relative times, new
/// posts in the fakes). Tests override it with a fixed clock.
final communityClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FakeFeedRepository(now: ref.watch(communityClockProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => FakeChatRepository(now: ref.watch(communityClockProvider)),
);

/// Guides are bundled with the app in version 1.
final guidesRepositoryProvider = Provider<GuidesRepository>((ref) => const BundledGuidesRepository());
