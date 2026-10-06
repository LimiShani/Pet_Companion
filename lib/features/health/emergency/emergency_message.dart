import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../access/access_provider.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/primary_button.dart';
import '../../../presentation/pet_words.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../../../presentation/health_format.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../presentation/health_widgets.dart';
import 'contact_actions.dart';
import '../../../platform/contact_launcher.dart';

/// One removable line of the pre-filled message.
class MessageLine {
  const MessageLine(this.key, this.text);

  /// Stable name of the line ("pet", "allergies", "conditions", "medicines",
  /// "microchip").
  final String key;
  final String text;
}

String _lowerFirst(String text) =>
    text.isEmpty ? text : '${text[0].toLowerCase()}${text.substring(1)}';

/// The essentials a vet needs, one line each, in the language of [format]
/// (the app's language: the owner reads the message before it goes out).
/// Lines with nothing to say are left out; nothing is invented.
///
/// In Hebrew every name and number is kept in one piece with invisible
/// direction marks. They stay in the text that is handed to the messaging
/// app, so the lines read in the right order there too.
List<MessageLine> emergencyMessageLines(
  HealthFormat format,
  HealthSummary summary,
) {
  final l10n = format.l10n;
  final pet = summary.pet;
  final profile = summary.profile;
  final grams = SpeciesSettings.of(pet.species).weightInGrams;
  final weight = summary.weightKg;
  final breed = petBreedText(format.pets, pet);
  final age = petAgeText(format.pets, pet);
  final facts = format.commas([
    _lowerFirst(petSpeciesText(format.pets, pet.species)),
    ?breed,
    if (age != null) _lowerFirst(age),
    if (weight != null) format.weight(weight, grams: grams),
  ]);
  String list(List<String> items, bool noneKnown) => items.isNotEmpty
      ? format.semicolons(items)
      : noneKnown
      ? l10n.messageNoneKnown
      : '';
  final allergies = list(profile.allergies, profile.allergiesNoneKnown);
  final conditions = list(profile.conditions, profile.conditionsNoneKnown);
  final medicines = format.semicolons([
    for (final m in summary.medications)
      format.instructions(m).isEmpty
          ? m.displayName
          : l10n.messageMedicineLine(m.displayName, format.instructions(m)),
  ]);
  final chip = profile.microchip.trim();
  return [
    MessageLine('pet', l10n.messagePetLine(pet.name, facts)),
    if (allergies.isNotEmpty)
      MessageLine('allergies', l10n.messageAllergies(allergies)),
    if (conditions.isNotEmpty)
      MessageLine('conditions', l10n.messageConditions(conditions)),
    if (medicines.isNotEmpty)
      MessageLine('medicines', l10n.messageMedicines(medicines)),
    if (chip.isNotEmpty)
      MessageLine('microchip', l10n.messageMicrochip(format.ltrInLine(chip))),
  ];
}

/// "Hello, this is Alex, Kelly's owner." [petName] is `null` while the
/// pet's details are not at hand.
String emergencyGreeting(
  HealthL10n l10n, {
  required String ownerName,
  required String? petName,
}) {
  final owner = ownerName.trim();
  if (petName == null) {
    return owner.isEmpty
        ? l10n.greetingOwnerNoPet
        : l10n.greetingNamedNoPet(owner);
  }
  return owner.isEmpty
      ? l10n.greetingOwner(petName)
      : l10n.greetingNamed(owner, petName);
}

/// The whole message: greeting, what the owner typed, then the [lines].
String composeEmergencyMessage(
  HealthL10n l10n, {
  required String ownerName,
  required String? petName,
  required String whatHappened,
  required List<String> lines,
}) {
  final typed = whatHappened.trim();
  return [
    emergencyGreeting(l10n, ownerName: ownerName, petName: petName),
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
    EmergencyMessageSheet(
      petId: petId,
      recipientName: recipientName,
      phone: phone,
      onWhatsApp: onWhatsApp,
    ),
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
  ConsumerState<EmergencyMessageSheet> createState() =>
      _EmergencyMessageSheetState();
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
    if (!ref.read(capabilityProvider('health.emergency.export'))) return;
    final launcher = ref.read(contactLauncherProvider);
    final opened = await launchOrExplain(
      context,
      launch: () => whatsApp
          ? launcher.whatsApp(widget.phone, message)
          : launcher.textMessage(widget.phone, message),
      problem: whatsApp
          ? context.healthL10n.couldNotOpenWhatsApp
          : context.healthL10n.couldNotOpenMessaging,
      copyLabel: context.healthL10n.copyMessage,
      copyText: message,
    );
    if (opened && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(healthSummaryProvider(widget.petId));
    final data = summary.value;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final allLines = data == null
        ? const <MessageLine>[]
        : emergencyMessageLines(format, data);
    final lines = [
      for (final line in allLines)
        if (!_removed.contains(line.key)) line,
    ];
    final petName = data?.pet.name;
    final greeting = emergencyGreeting(
      l10n,
      ownerName: data?.ownerName ?? '',
      petName: petName,
    );
    final message = composeEmergencyMessage(
      l10n,
      ownerName: data?.ownerName ?? '',
      petName: petName,
      whatHappened: _typed.text,
      lines: [for (final line in lines) line.text],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(
          l10n.messageTo(widget.recipientName),
          subtitle: format.ltrInLine(widget.phone),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('message-what'),
          controller: _typed,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.whatIsHappening),
        ),
        FormLabel(l10n.messagePreviewLabel),
        HealthCard(
          padding: const EdgeInsetsDirectional.only(
            start: 14,
            end: 6,
            top: 12,
            bottom: 8,
          ),
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
                  child: TypedText(
                    _typed.text.trim(),
                    style: AppText.secondary.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (summary.isLoading && data == null)
                const Padding(
                  padding: EdgeInsetsDirectional.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (summary.hasError && data == null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8, top: 8),
                  child: Text(
                    petName == null
                        ? l10n.messageDetailsNotLoadedNoPet
                        : l10n.messageDetailsNotLoaded(petName),
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
                      tooltip: l10n.removeThisLine,
                      icon: const AppIcon(Icons.close_rounded, size: 18),
                      color: AppColors.brown,
                      constraints: const BoxConstraints(
                        minWidth: kHealthTapTarget,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              if (_removed.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: HealthLink(
                    l10n.putRemovedLinesBack,
                    onPressed: () => setState(_removed.clear),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (ref.watch(capabilityProvider('health.emergency.export')))
          PrimaryButton(
            label: l10n.openInMessages,
            onPressed: () => _open(message, whatsApp: false),
          ),
        if (widget.onWhatsApp) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _open(message, whatsApp: true),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            child: Text(l10n.openInWhatsApp),
          ),
        ],
        const SizedBox(height: 12),
        FinePrint(l10n.messageFinePrint),
      ],
    );
  }
}
