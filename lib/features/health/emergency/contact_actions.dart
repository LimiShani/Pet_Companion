import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../widgets/health_widgets.dart';
import 'contact_launcher.dart';
import 'emergency_message.dart';

/// Runs [launch]; when the phone could not open the other app, says so and
/// offers to copy [copyText] instead.
Future<bool> launchOrExplain(
  BuildContext context, {
  required Future<bool> Function() launch,
  required String problem,
  required String copyLabel,
  required String copyText,
}) async {
  final opened = await launch();
  if (opened || !context.mounted) return opened;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(problem),
      content: SelectableText(copyText),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyText));
            Navigator.of(context).pop();
          },
          child: Text(copyLabel),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
  return false;
}

/// Opens the dialler with [phone]. The owner presses call there.
Future<bool> callContact(BuildContext context, WidgetRef ref, String phone) => launchOrExplain(
  context,
  launch: () => ref.read(contactLauncherProvider).call(phone),
  problem: 'Could not open the phone app',
  copyLabel: 'Copy number',
  copyText: phone,
);

/// Opens the maps app on [address].
Future<bool> openContactMap(BuildContext context, WidgetRef ref, String address) => launchOrExplain(
  context,
  launch: () => ref.read(contactLauncherProvider).openMap(address),
  problem: 'Could not open the maps app',
  copyLabel: 'Copy address',
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (number != null) ...[
          FilledButton.icon(
            key: ValueKey('call-$tag'),
            style: _filled,
            onPressed: () => callContact(context, ref, number),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Call'),
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
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Message'),
          ),
        ] else if (onAddPhone != null)
          OutlinedButton.icon(
            key: ValueKey('add-phone-$tag'),
            style: _outlined,
            onPressed: onAddPhone,
            icon: const Icon(Icons.add_call, size: 18),
            label: const Text('Add a phone number'),
          ),
        if (place != null)
          OutlinedButton.icon(
            key: ValueKey('map-$tag'),
            style: _outlined,
            onPressed: () => openContactMap(context, ref, place),
            icon: const Icon(Icons.place_rounded, size: 18),
            label: const Text('Map'),
          ),
      ],
    );
  }
}

/// One contact in the emergency sheet and on the Emergency card: who it
/// is, one line of detail, and the action buttons.
class EmergencyContactCard extends StatelessWidget {
  const EmergencyContactCard({
    super.key,
    required this.petId,
    required this.tag,
    required this.role,
    required this.name,
    required this.icon,
    this.detail,
    this.phone,
    this.onWhatsApp = false,
    this.address,
    this.onAddPhone,
  });

  final String petId;
  final String tag;

  /// "Regular vet", "Emergency vet (24 h)", "Emergency contact".
  final String role;
  final String name;
  final IconData icon;
  final String? detail;
  final String? phone;
  final bool onWhatsApp;
  final String? address;
  final VoidCallback? onAddPhone;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconDisc(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role, style: AppText.label.copyWith(color: AppColors.brown)),
                    Text(name, style: AppText.cardTitle),
                    if (phone != null) Text(phone!, style: AppText.secondary.copyWith(color: AppColors.brown)),
                    if (detail != null) Text(detail!, style: AppText.secondary.copyWith(color: AppColors.brown)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ContactActionButtons(
            petId: petId,
            tag: tag,
            name: name,
            phone: phone,
            onWhatsApp: onWhatsApp,
            address: address,
            onAddPhone: onAddPhone,
          ),
        ],
      ),
    );
  }
}
