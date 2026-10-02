import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../health/emergency/emergency.dart';

/// Opens the selected pet's emergency and vet sheet (the Health tab's): the
/// regular vet, the emergency vet and the emergency contact.
Future<void> contactProfessional(BuildContext context, WidgetRef ref) async {
  final petId = ref.read(selectedPetProvider).id;
  if (petId.isEmpty) return;
  await showEmergencySheet(context, petId);
}

/// One slim line saying that members' answers are personal experience and
/// not professional advice, with the way to a professional. Always shown:
/// there is nothing to dismiss. The whole line is the tap target.
class AdviceNotice extends ConsumerWidget {
  const AdviceNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final radius = BorderRadius.circular(AppSpacing.fieldRadius);
    final style = AppText.label.copyWith(color: AppColors.ink, height: 1.4);

    return Semantics(
      button: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => contactProfessional(context, ref),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const AppIcon(Icons.info_outline_rounded, size: 18, color: AppColors.brown),
                  const SizedBox(width: 8),
                  Expanded(
                    // Two whole messages side by side: the notice, then the
                    // action that goes with it.
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${l10n.adviceNotice} '),
                          TextSpan(
                            text: l10n.contactProfessional,
                            style: style.copyWith(color: AppColors.coralDark, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
