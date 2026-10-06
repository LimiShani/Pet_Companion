import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../access/access_provider.dart';
import '../../../platform/session.dart';

import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../feed/feed_controller.dart' show noRetry;

/// The chat rooms, in display order.
final chatChannelsProvider = FutureProvider<List<ChatChannel>>((ref) {
  ref.watch(sessionEpochProvider);
  if (!ref.watch(capabilityProvider('community.chat.view'))) {
    return Future.value(const <ChatChannel>[]);
  }
  return ref.watch(chatRepositoryProvider).fetchChannels();
}, retry: noRetry);

/// The live messages of one room, oldest first. Subscribed only while a
/// conversation screen is open.
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, channelId) {
      ref.watch(sessionEpochProvider);
      if (!ref.watch(capabilityProvider('community.chat.view'))) {
        return Stream.value(const <ChatMessage>[]);
      }
      return ref.watch(chatRepositoryProvider).watchMessages(channelId);
    }, retry: noRetry);

/// Icon of a room, by its id. Rooms added later get the default.
IconData chatChannelIcon(String channelId) => switch (channelId) {
  'general' => Icons.chat_bubble_rounded,
  'puppies' => Icons.pets_rounded,
  'training' => Icons.school_rounded,
  'seniors' => Icons.favorite_rounded,
  'kittens' => Icons.pets_rounded,
  'cat-litter' => Icons.cleaning_services_rounded,
  'cat-behaviour' => Icons.toys_rounded,
  'senior-cats' => Icons.favorite_rounded,
  'health' => Icons.medical_services_rounded,
  _ => Icons.forum_rounded,
};
