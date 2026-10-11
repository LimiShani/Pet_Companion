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
    final l10n = context.accessL10n;
    return Scaffold(
      body: Column(
        children: [
          CoralHeader(title: l10n.gateTitle, showBack: true),
          Expanded(
            child: Center(
              child: EmptyState(
                icon: Icons.lock_outline_rounded,
                title: l10n.gateUnavailable,
                message: l10n.gateMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
