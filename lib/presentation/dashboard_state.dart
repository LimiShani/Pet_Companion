import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../services/care/state/care_providers.dart';

class HomeCardState extends ConsumerWidget {
  const HomeCardState({super.key, required this.value, required this.petId});

  final AsyncValue<Object?> value;
  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (value.hasError) {
      return InkWell(
        onTap: () => ref.invalidate(careSettingsProvider(petId)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(context.careL10n.loadFailed, style: AppText.body),
        ),
      );
    }
    // A quiet blank of the body's height: the data is usually there in a
    // moment, and a spinner on every card would only flicker.
    return const SizedBox(height: 56);
  }
}
