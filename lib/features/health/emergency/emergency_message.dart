import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'contact_actions.dart';
import 'contact_launcher.dart';

/// One removable line of the pre-filled message.
class MessageLine {
  const MessageLine(this.key, this.text);

  /// Stable name of the line ("pet", "allergies", "conditions", "medicines",
  /// "microchip").
  final String key;
  final String text;
}

/// The essentials a vet needs, one line each. Lines with nothing to say
/// are left out; nothing is invented.
List<MessageLine> emergencyMessageLines(HealthSummary summary) {
  final pet = summary.pet;
  final profile = summary.profile;
  final grams = SpeciesSettings.of(pet.species).weightInGrams;
  final weight = summary.weightKg;
  final facts = [
    pet.species.label.toLowerCase(),
    if ((pet.breed ?? '').trim().isNotEmpty) pet.breed!.trim(),
    if (pet.ageYears != null) '${formatNumber(pet.ageYears!)} years',
    if (weight != null) formatWeight(weight, grams: grams),
  ];
  String list(List<String> items, bool noneKnown) => items.isNotEmpty
      ? items.join('; ')
      : noneKnown
          ? 'none known'
          : '';
  final allergies = list(profile.allergies, profile.allergiesNoneKnown);
  final conditions = list(profile.conditions, profile.conditionsNoneKnown);
  final medicines = [
    for (final m in summary.medications)
      m.instructionLine.isEmpty ? m.displayName : '${m.displayName}, ${m.instructionLine}',
  ].join('; ');
  return [
    MessageLine('pet', '${pet.name}: ${facts.join(', ')}'),
    if (allergies.isNotEmpty) MessageLine('allergies', 'Allergies: $allergies'),
    if (conditions.isNotEmpty) MessageLine('conditions', 'Conditions: $conditions'),
    if (medicines.isNotEmpty) MessageLine('medicines', 'Medicines: $medicines'),
    if (profile.microchip.trim().isNotEmpty) MessageLine('microchip', 'Microchip: ${profile.microchip.trim()}'),
  ];
}

/// "Hello, this is Alex, Kelly's owner."
String emergencyGreeting({required String ownerName, required String petName}) {
  final owner = ownerName.trim();
  return owner.isEmpty ? "Hello, I am $petName's owner." : "Hello, this is $owner, $petName's owner.";
}

/// The whole message: greeting, what the owner typed, then the [lines].
String composeEmergencyMessage({
  required String ownerName,
  required String petName,
  required String whatHappened,
  required List<String> lines,
}) {
  final typed = whatHappened.trim();
  return [
    emergencyGreeting(ownerName: ownerName, petName: petName),
    if (typed.isNotEmpty) typed,
    if (lines.isNotEmpty) '',
    ...lines,
  ].join('\n');
}

/// Opens the message sheet for one recipient: the owner types what is
/// happening, sees the whole text, removes any line, and opens the phone's
/// messaging app (or WhatsApp, when [onWhatsApp]) with it. Nothing is sent
/// by the app.
Future<void> showEmergencyMessageSheet(
  BuildContext context, {
  required String petId,
  required String recipientName,
  required String phone,
  bool onWhatsApp = false,
}) {
  return showHealthSheet<void>(
    context,
    EmergencyMessageSheet(petId: petId, recipientName: recipientName, phone: phone, onWhatsApp: onWhatsApp),
  );
}

class EmergencyMessageSheet extends ConsumerStatefulWidget {
  const EmergencyMessageSheet({
    super.key,
    required this.petId,
    required this.recipientName,
    required this.phone,
    this.onWhatsApp = false,
  });

  final String petId;
  final String recipientName;
  final String phone;
  final bool onWhatsApp;

  @override
  ConsumerState<EmergencyMessageSheet> createState() => _EmergencyMessageSheetState();
}

class _EmergencyMessageSheetState extends ConsumerState<EmergencyMessageSheet> {
  final _typed = TextEditingController();
  final _removed = <String>{};

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _open(String message, {required bool whatsApp}) async {
    final launcher = ref.read(contactLauncherProvider);
    final opened = await launchOrExplain(
      context,
      launch: () => whatsApp ? launcher.whatsApp(widget.phone, message) : launcher.textMessage(widget.phone, message),
      problem: whatsApp ? 'Could not open WhatsApp' : 'Could not open the messaging app',
      copyLabel: 'Copy message',
      copyText: message,
    );
    if (opened && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(healthSummaryProvider(widget.petId));
    final data = summary.value;
    final allLines = data == null ? const <MessageLine>[] : emergencyMessageLines(data);
    final lines = [
      for (final line in allLines)
        if (!_removed.contains(line.key)) line,
    ];
    final petName = data?.pet.name ?? 'my pet';
    final greeting = emergencyGreeting(ownerName: data?.ownerName ?? '', petName: petName);
    final message = composeEmergencyMessage(
      ownerName: data?.ownerName ?? '',
      petName: petName,
      whatHappened: _typed.text,
      lines: [for (final line in lines) line.text],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle('Message to ${widget.recipientName}', subtitle: widget.phone),
        const SizedBox(height: 12),
        TextField(
          key: const Key('message-what'),
          controller: _typed,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What is happening?'),
        ),
        const FormLabel('This is what will be written'),
        HealthCard(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 12, bottom: 8),
          radius: AppSpacing.fieldRadius,
          child: Column(
            key: const Key('message-preview'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(greeting, style: AppText.secondary),
              ),
              if (_typed.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8, top: 2),
                  child: Text(_typed.text.trim(), style: AppText.secondary.copyWith(fontWeight: FontWeight.w800)),
                ),
              if (summary.isLoading && data == null)
                const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
              else if (summary.hasError && data == null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8, top: 8),
                  child: Text(
                    "${petName == 'my pet' ? 'The pet' : petName}'s details could not be loaded, so only your own words will be sent.",
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                ),
              if (lines.isNotEmpty) const Divider(height: 16),
              for (final line in lines)
                Row(
                  children: [
                    Expanded(child: Text(line.text, style: AppText.secondary)),
                    IconButton(
                      key: ValueKey('remove-line-${line.key}'),
                      onPressed: () => setState(() => _removed.add(line.key)),
                      tooltip: 'Remove this line',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.brown,
                      constraints: const BoxConstraints(minWidth: kHealthTapTarget, minHeight: 40),
                    ),
                  ],
                ),
              if (_removed.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: HealthLink('Put the removed lines back', onPressed: () => setState(_removed.clear)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Open in Messages', onPressed: () => _open(message, whatsApp: false)),
        if (widget.onWhatsApp) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _open(message, whatsApp: true),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
            child: const Text('Open in WhatsApp'),
          ),
        ],
        const SizedBox(height: 12),
        const FinePrint('Nothing is sent until you press send in that app. In an emergency, calling is faster.'),
      ],
    );
  }
}
