import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../navigation/app_router.dart';

/// Close account-owned forms, sheets and dialogs when authentication changes.
/// The router handles declarative pages; imperative pages need this teardown.
class SessionNavigationHost extends ConsumerWidget {
  const SessionNavigationHost({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous == null || previous.value?.id == next.value?.id) return;
      scheduleMicrotask(() {
        if (!context.mounted) return;
        ref
            .read(routerProvider)
            .routerDelegate
            .navigatorKey
            .currentState
            ?.popUntil((route) => route.settings is Page);
      });
    });
    return child;
  }
}
