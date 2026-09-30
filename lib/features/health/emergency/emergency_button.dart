import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../health_format.dart';
import '../state/health_keeper.dart';
import '../widgets/health_widgets.dart';
import 'emergency_contacts.dart';
import 'emergency_sheet.dart';

/// The one place that defines how the emergency button looks.
///
/// On coral (the Home top bar, the Health header) it is a filled white
/// pill with dark coral text and icon: white 13 px text on coral is only
/// about 3:1, and an outline reads as an unselected pet pill. On light
/// surfaces it is filled dark coral with white text.
abstract final class EmergencyButtonStyle {
  static const onCoralBackground = AppColors.white;
  static const onCoralForeground = AppColors.coralDark;
  static const onLightBackground = AppColors.coralDark;
  static const onLightForeground = AppColors.white;

  /// The dot shown when no phone number is saved for the pet.
  static const dot = AppColors.yellow;

  static const label = 'Emergency';
  static const icon = emergencyIcon;
  static const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);

  /// Height of the visible pill; the tap target is [kHealthTapTarget].
  static const pillHeight = 40.0;
}

/// The emergency entry point: a pill (or, [compact], a round icon button)
/// that opens the emergency actions for [petId] with [showEmergencySheet].
///
/// It stays enabled whatever the state of the data. When no phone number
/// is saved for the pet yet it shows a small yellow dot ([showStatusDot]),
/// and the sheet then opens on the add-a-vet prompt.
class EmergencyButton extends ConsumerWidget {
  const EmergencyButton({
    super.key,
    required this.petId,
    this.compact = false,
    this.onCoral = true,
    this.showStatusDot = true,
  });

  final String petId;

  /// Round icon-only button instead of the pill with its label.
  final bool compact;

  /// Colours for a coral background (true) or a light surface (false).
  final bool onCoral;

  /// Show the yellow dot while no phone number is saved.
  final bool showStatusDot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = onCoral ? EmergencyButtonStyle.onCoralBackground : EmergencyButtonStyle.onLightBackground;
    final foreground = onCoral ? EmergencyButtonStyle.onCoralForeground : EmergencyButtonStyle.onLightForeground;

    final petName = ref.watch(
      petsProvider.select((pets) {
        for (final pet in pets) {
          if (pet.id == petId) return pet.name;
        }
        return null;
      }),
    );
    // Only "loaded, and nothing to call" shows the dot: loading and load
    // errors leave the button as it is.
    final contacts = showStatusDot ? ref.watch(emergencyContactsProvider(petId)) : null;
    final nothingToCall = contacts != null && contacts.hasValue && !contacts.hasError && !contacts.value!.hasPhone;

    final label = petName == null ? 'Emergency contacts' : 'Emergency contacts for $petName';
    final pill = Container(
      height: EmergencyButtonStyle.pillHeight,
      constraints: const BoxConstraints(minWidth: EmergencyButtonStyle.pillHeight),
      padding: compact ? EdgeInsets.zero : const EdgeInsetsDirectional.only(start: 12, end: 14),
      decoration: BoxDecoration(color: background, borderRadius: const BorderRadius.all(Radius.circular(999))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(EmergencyButtonStyle.icon, size: compact ? 22 : 18, color: foreground),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              EmergencyButtonStyle.label,
              maxLines: 1,
              style: EmergencyButtonStyle.textStyle.copyWith(color: foreground),
            ),
          ],
        ],
      ),
    );

    return HealthKeeper(
      petId: petId,
      child: _button(context, label: label, pill: pill, nothingToCall: nothingToCall),
    );
  }

  Widget _button(BuildContext context, {required String label, required Widget pill, required bool nothingToCall}) {
    return Semantics(
      button: true,
      label: nothingToCall ? '$label. No phone number saved yet' : label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showEmergencySheet(context, petId),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: kHealthTapTarget, minHeight: kHealthTapTarget),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  pill,
                  if (nothingToCall)
                    PositionedDirectional(
                      top: -2,
                      end: -2,
                      child: Container(
                        key: const Key('emergency-dot'),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: EmergencyButtonStyle.dot,
                          shape: BoxShape.circle,
                          border: Border.all(color: onCoral ? AppColors.coral : AppColors.white, width: 2),
                        ),
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
