import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../health/emergency/emergency.dart';

/// The standing line in chat rooms and under a post's comments.
const adviceNoticeText = 'Members share personal experience, not professional advice.';

/// The action that goes with [adviceNoticeText] and with a guide's closing
/// note.
const contactProfessionalLabel = 'Contact a professional';

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
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.brown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '$adviceNoticeText '),
                          TextSpan(
                            text: contactProfessionalLabel,
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
