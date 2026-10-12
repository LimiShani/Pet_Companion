import '../../../presentation/launch_or_explain.dart';
export '../../../presentation/launch_or_explain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_widgets.dart';
import '../../../platform/contact_launcher.dart';
import 'emergency_message.dart';

/// Runs [launch]; when the phone could not open the other app, says so and
/// offers to copy [copyText] instead. [copyIsNumber]: [copyText] is a phone
/// number, which reads left to right on every screen.

/// Opens the dialler with [phone]. The owner presses call there.
Future<bool> callContact(BuildContext context, WidgetRef ref, String phone) =>
    launchOrExplain(
      context,
      launch: () => ref.read(contactLauncherProvider).call(phone),
      problem: context.healthL10n.couldNotOpenPhone,
      copyLabel: context.healthL10n.copyNumber,
      copyText: phone,
      copyIsNumber: true,
    );

/// Opens the maps app on [address].
Future<bool> openContactMap(
  BuildContext context,
  WidgetRef ref,
  String address,
) => launchOrExplain(
  context,
  launch: () => ref.read(contactLauncherProvider).openMap(address),
  problem: context.healthL10n.couldNotOpenMaps,
  copyLabel: context.healthL10n.copyAddress,
  copyText: address,
);

/// The Call, Message and Map buttons of one contact. Buttons whose data is
/// missing are left out; with no phone number at all, [onAddPhone] is
/// offered instead.
class ContactActionButtons extends ConsumerWidget {
  const ContactActionButtons({
    super.key,
    required this.petId,
    required this.tag,
    required this.name,
    this.phone,
    this.onWhatsApp = false,
    this.address,
    this.onAddPhone,
  });

  final String petId;

  /// Distinguishes the buttons of several contacts on one screen: the keys
  /// are `call-<tag>`, `message-<tag>` and `map-<tag>`.
  final String tag;
  final String name;
  final String? phone;
  final bool onWhatsApp;
  final String? address;
  final VoidCallback? onAddPhone;

  static final _filled = FilledButton.styleFrom(
    minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    textStyle: AppText.button(14),
  );
  static final _outlined = OutlinedButton.styleFrom(
    minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    textStyle: AppText.button(14),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = phone;
    final place = address;
    final l10n = context.healthL10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (number != null) ...[
          FilledButton.icon(
            key: ValueKey('call-$tag'),
            style: _filled,
            onPressed: () => callContact(context, ref, number),
            icon: const AppIcon(Icons.call_rounded, size: 18),
            label: Text(l10n.actionCall),
          ),
          OutlinedButton.icon(
            key: ValueKey('message-$tag'),
            style: _outlined,
            onPressed: () => showEmergencyMessageSheet(
              context,
              petId: petId,
              recipientName: name,
              phone: number,
              onWhatsApp: onWhatsApp,
            ),
            icon: const AppIcon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(l10n.actionMessage),
          ),
        ] else if (onAddPhone != null)
          OutlinedButton.icon(
            key: ValueKey('add-phone-$tag'),
            style: _outlined,
            onPressed: onAddPhone,
            icon: const AppIcon(Icons.add_call, size: 18),
            label: Text(l10n.addPhoneNumber),
          ),
        if (place != null)
          OutlinedButton.icon(
            key: ValueKey('map-$tag'),
            style: _outlined,
            onPressed: () => openContactMap(context, ref, place),
            icon: const AppIcon(Icons.place_rounded, size: 18),
            label: Text(l10n.actionMap),
          ),
      ],
    );
  }
}

//// Who a contact is, as the emergency sheet shows it: the role in small
/// capitals, the name, and the phone number when [phone] is given.
class _ContactLines extends StatelessWidget {
  const _ContactLines({
    required this.role,
    required this.name,
    required this.nameStyle,
    this.phone,
  });

  final String role;
  final String name;
  final TextStyle nameStyle;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // Small capitals in English; Hebrew has no capitals to change.
          role.toUpperCase(),
          style: AppText.label.copyWith(
            color: AppColors.brown,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        TypedText(name, style: nameStyle),
        // A phone number reads left to right on every screen.
        if (phone != null)
          Text(
            HealthFormat.of(context).ltrInLine(phone!),
            style: AppText.secondary.copyWith(
              color: AppColors.brown,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

/// The one contact the emergency sheet leads with: who it is, its number,
/// one big "Call now", and "Message" and "Directions" under it. Without a
/// phone number, [onAddPhone] takes the place of "Call now".
///
/// The keys are `call-<tag>`, `message-<tag>`, `map-<tag>` and
/// `add-phone-<tag>`, as on [ContactActionButtons].
class EmergencyPrimaryCard extends ConsumerWidget {
  const EmergencyPrimaryCard({
    super.key,
    required this.petId,
    required this.tag,
    required this.role,
    required this.name,
    required this.icon,
    this.phone,
    this.onWhatsApp = false,
    this.address,
    this.onAddPhone,
  });

  final String petId;
  final String tag;

  /// "Emergency vet (24 h)", "Regular vet", "Emergency contact".
  final String role;
  final String name;
  final IconData icon;
  final String? phone;
  final bool onWhatsApp;
  final String? address;
  final VoidCallback? onAddPhone;

  static final _callNow = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    textStyle: AppText.button(16),
  );
  static final _half = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(kHealthTapTarget),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: AppText.button(14),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = phone;
    final place = address;
    final l10n = context.healthL10n;
    final under = <Widget>[
      if (number != null)
        OutlinedButton(
          key: ValueKey('message-$tag'),
          style: _half,
          onPressed: () => showEmergencyMessageSheet(
            context,
            petId: petId,
            recipientName: name,
            phone: number,
            onWhatsApp: onWhatsApp,
          ),
          child: Text(
            l10n.actionMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (place != null)
        OutlinedButton(
          key: ValueKey('map-$tag'),
          style: _half,
          onPressed: () => openContactMap(context, ref, place),
          child: Text(
            l10n.emergencyDirections,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    return HealthCard(
      key: const Key('emergency-primary'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconDisc(icon, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactLines(
                  role: role,
                  name: name,
                  phone: number,
                  nameStyle: AppText.rowTitle.copyWith(fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (number != null)
            FilledButton.icon(
              key: ValueKey('call-$tag'),
              style: _callNow,
              onPressed: () => callContact(context, ref, number),
              icon: const AppIcon(Icons.call_rounded, size: 20),
              label: Text(
                l10n.emergencyCallNow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (onAddPhone != null)
            FilledButton.icon(
              key: ValueKey('add-phone-$tag'),
              style: _callNow,
              onPressed: onAddPhone,
              icon: const AppIcon(Icons.add_call, size: 20),
              label: Text(
                l10n.addPhoneNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (under.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < under.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: under[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A contact after the first one on the emergency sheet: who it is, and
/// two round buttons at the end, Message and Call. Without a phone number,
/// one round button for [onAddPhone] instead.
///
/// The keys are `message-<tag>`, `call-<tag>` and `add-phone-<tag>`.
class EmergencyContactRow extends ConsumerWidget {
  const EmergencyContactRow({
    super.key,
    required this.petId,
    required this.tag,
    required this.role,
    required this.name,
    this.phone,
    this.onWhatsApp = false,
    this.onAddPhone,
  });

  final String petId;
  final String tag;
  final String role;
  final String name;
  final String? phone;
  final bool onWhatsApp;
  final VoidCallback? onAddPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = phone;
    final add = onAddPhone;
    final l10n = context.healthL10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _ContactLines(
              role: role,
              name: name,
              nameStyle: AppText.cardTitle.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (number != null) ...[
            _RoundButton(
              key: ValueKey('message-$tag'),
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: l10n.emergencyMessageNamed(name),
              onPressed: () => showEmergencyMessageSheet(
                context,
                petId: petId,
                recipientName: name,
                phone: number,
                onWhatsApp: onWhatsApp,
              ),
            ),
            _RoundButton(
              key: ValueKey('call-$tag'),
              icon: Icons.call_rounded,
              tooltip: l10n.emergencyCallNamed(name),
              filled: true,
              onPressed: () => callContact(context, ref, number),
            ),
          ] else if (add != null)
            _RoundButton(
              key: ValueKey('add-phone-$tag'),
              icon: Icons.add_call,
              tooltip: l10n.addPhoneNumber,
              onPressed: add,
            ),
        ],
      ),
    );
  }
}

/// A round 40 px icon button inside a 48 px tap target: coral-dark and
/// filled, or white with a coral-dark ring. [tooltip] is also what a screen
/// reader says.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = filled ? AppColors.white : AppColors.coralDark;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: filled ? AppColors.coralDark : AppColors.white,
        foregroundColor: color,
        side: filled
            ? null
            : const BorderSide(color: AppColors.coralDark, width: 2),
      ),
      icon: AppIcon(icon, size: 18, color: color),
    );
  }
}
