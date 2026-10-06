import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../chat/chat_providers.dart';
import '../feed/feed_controller.dart';
import '../safety/safety_providers.dart';

/// Keeps the Community tab's lists active while [child] is mounted, for the
/// reason given on `HealthKeeper`: the tab stays below a chat room, a post
/// and the safety page, which change what it shows (a block, a read room),
/// and it must follow without being rebuilt in the middle of a frame when
/// it comes back into view. With [channelId] it keeps that room's
/// conversation too (a room stays below the photo viewer and the sheets).
class CommunityKeeper extends StatefulWidget {
  const CommunityKeeper({super.key, required this.child, this.channelId});

  final Widget child;
  final String? channelId;

  @override
  State<CommunityKeeper> createState() => _CommunityKeeperState();
}

class _CommunityKeeperState extends State<CommunityKeeper> {
  ProviderContainer? _container;
  final _subscriptions = <ProviderSubscription<Object?>>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context);
    if (!identical(container, _container)) {
      _container = container;
      _listen();
    }
  }

  @override
  void didUpdateWidget(CommunityKeeper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) _listen();
  }

  void _listen() {
    _close();
    final container = _container!;
    void keep<T>(ProviderListenable<T> provider) => _subscriptions.add(
      container.listen<T>(provider, (_, _) {}, onError: (_, _) {}),
    );
    keep(blockedIdsProvider);
    keep(visiblePostsProvider);
    keep(chatRoomSummariesProvider);
    if (widget.channelId case final id?) keep(chatConversationProvider(id));
  }

  void _close() {
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
