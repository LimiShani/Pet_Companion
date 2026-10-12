import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../platform/feature_ui.dart';
import '../../../access/access_provider.dart';

/// Opens the selected pet's emergency and vet sheet (the Health tab's): the
/// regular vet, the emergency vet and the emergency contact.
Future<void> contactProfessional(BuildContext context, WidgetRef ref) async {
  final petId = ref.read(selectedPetProvider).id;
  if (petId.isEmpty) return;
  await openFeature<Object>(context, 'emergency', petId);
}

/// Whether the line about advice at the top of the feed is hidden. Hidden
/// with its "Hide" button for the rest of this run of the app; it is back
/// the next time the app opens.
class FeedAdviceHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void hide() => state = true;
}

final feedAdviceHiddenProvider = NotifierProvider<FeedAdviceHidden, bool>(
  FeedAdviceHidden.new,
);

/// The feed's one line saying that members share experience, not
/// professional advice, with a "Hide" button. Shown once, above the first
/// post (not on every post page and room).
class FeedAdviceLine extends ConsumerWidget {
  const FeedAdviceLine({super.key});

  static const lineKey = Key('feed-advice-line');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(feedAdviceHiddenProvider)) return const SizedBox.shrink();
    final l10n = context.communityL10n;

    return Padding(
      key: lineKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        8,
        AppSpacing.screen - 8,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.adviceNotice,
              style: AppText.label.copyWith(color: AppColors.brown),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => ref.read(feedAdviceHiddenProvider.notifier).hide(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.coralDark,
              textStyle: AppText.label.copyWith(fontWeight: FontWeight.w800),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(l10n.adviceHide),
          ),
        ],
      ),
    );
  }
}

/// One slim line saying that members' answers are personal experience and
/// not professional advice, with the way to a professional. The whole line
/// is the tap target. Always shown where it is placed: the health room and
/// the room info sheet.
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
          onTap: ref.watch(capabilityProvider('health.emergency.view'))
              ? () => contactProfessional(context, ref)
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const AppIcon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.brown,
                  ),
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
                            style: style.copyWith(
                              color: AppColors.coralDark,
                              fontWeight: FontWeight.w800,
                            ),
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
