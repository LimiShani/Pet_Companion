import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../widgets/coral_header.dart';
import '../widgets/empty_state.dart';
import 'access_provider.dart';

/// The builder is lazy: denied features must not subscribe or fetch data.
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.capability,
    required this.builder,
    this.hidden = false,
  });
  final String capability;
  final WidgetBuilder builder;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(capabilityProvider(capability))) return builder(context);
    if (hidden) return const SizedBox.shrink();
    final hebrew = context.isRtl;
    return Scaffold(
      body: Column(
        children: [
          CoralHeader(
            title: hebrew ? 'גישה לתכונה' : 'Feature access',
            showBack: true,
          ),
          Expanded(
            child: Center(
              child: EmptyState(
                icon: Icons.lock_outline_rounded,
                title: hebrew ? 'התכונה אינה זמינה' : 'Feature unavailable',
                message: hebrew
                    ? 'אין לחשבון שלך גישה לתכונה הזאת כרגע.'
                    : 'Your account does not have access to this feature right now.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
