import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../platform/contact_launcher.dart';
import '../../platform/feature_ui.dart';
import '../../presentation/health_strings.dart';
import '../../presentation/health_widgets.dart';
import '../../presentation/launch_or_explain.dart';
import '../../services/findvet/data/vet_models.dart';
import '../../services/pet_records/data/health_models.dart';
import '../../services/pet_records/state/emergency_contacts.dart';
import '../../services/safety/data/food_safety.dart';
import '../../services/safety/data/safety_text.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_tag.dart';

/// The contact the Emergency sheet leads with, as the safety pages show it:
/// its role and name. `null` when nothing with a number is saved.
({String role, String name, String phone})? firstContactOf(
  BuildContext context,
  EmergencyContacts? contacts,
) {
  if (contacts == null) return null;
  final l10n = context.healthL10n;
  final emergency = contacts.emergencyVet;
  final regular = contacts.regularVet;
  final person = contacts.contact;
  if (emergency?.phone case final phone?) {
    return (role: l10n.vetRole(VetRole.emergency), name: emergency!.name, phone: phone);
  }
  if (regular?.phone case final phone?) {
    return (role: l10n.vetRole(VetRole.regular), name: regular!.name, phone: phone);
  }
  if (person?.phone case final phone?) {
    final name = person!.name.isEmpty ? l10n.emergencyContact : person.name;
    return (role: l10n.emergencyContact, name: name, phone: phone);
  }
  return null;
}

/// Dials the pet's first contact (the same one as the sheet's Call now),
/// or opens Find a vet's emergency path when nothing can be called.
Future<void> callFirstContact(
  BuildContext context,
  WidgetRef ref,
  String petId,
) async {
  EmergencyContacts? contacts;
  try {
    contacts = await ref.read(emergencyContactsProvider(petId).future);
  } catch (_) {
    contacts = null;
  }
  if (!context.mounted) return;
  final first = firstContactOf(context, contacts);
  if (first == null) {
    await openFindClinic(context);
    return;
  }
  await launchOrExplain(
    context,
    launch: () => ref.read(contactLauncherProvider).call(first.phone),
    problem: context.healthL10n.couldNotOpenPhone,
    copyLabel: context.healthL10n.copyNumber,
    copyText: first.phone,
    copyIsNumber: true,
  );
}

/// Find a vet's emergency path (clinics open now, nearest first).
Future<void> openFindClinic(BuildContext context) =>
    openFeature<Object>(context, 'find-vet', '', {
      'mode': VetSearchMode.emergency,
    });

/// The peach card at the top of a safety page: the first contact and one
/// full-width Call now; with nothing to call, "No vet saved? Find a clinic
/// nearby" instead.
class SafetyCallCard extends ConsumerWidget {
  const SafetyCallCard({super.key, required this.petId});

  static const callKey = Key('safety-call-now');
  static const findClinicKey = Key('safety-find-clinic');

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider(petId)).value;
    final first = firstContactOf(context, contacts);
    final l10n = context.healthL10n;
    final button = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: AppColors.coralDark,
      foregroundColor: AppColors.white,
      textStyle: AppText.button(16),
    );
    return HealthCard(
      key: const Key('safety-call-card'),
      color: AppColors.peach,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (first != null) ...[
            Text(
              first.role.toUpperCase(),
              style: AppText.label.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            TypedText(first.name, style: AppText.rowTitle.copyWith(fontSize: 17)),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: callKey,
              style: button,
              onPressed: () => callFirstContact(context, ref, petId),
              icon: const AppIcon(Icons.call_rounded, size: 20),
              label: Text(
                l10n.emergencyCallNow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            FilledButton.icon(
              key: findClinicKey,
              style: button,
              onPressed: () => openFindClinic(context),
              icon: const AppIcon(Icons.local_hospital_rounded, size: 20),
              label: Text(
                context.safetyL10n.noVetFindClinic,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

/// "Where this comes from": a folded card with the list's sources.
class SafetySourcesCard extends StatelessWidget {
  const SafetySourcesCard({super.key, required this.sources});

  static const tileKey = Key('safety-sources');

  final List<SafetySource> sources;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: tileKey,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            context.safetyL10n.sourcesTitle,
            style: AppText.cardTitle.copyWith(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${source.name}\n${source.url}',
                  textDirection: TextDirection.ltr,
                  style: AppText.label.copyWith(color: AppColors.brown),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The words of a food answer; `null` is "Ask your vet".
String foodLevelText(BuildContext context, FoodLevel? level) {
  final l10n = context.safetyL10n;
  return switch (level) {
    FoodLevel.safe => l10n.levelSafe,
    FoodLevel.aLittle => l10n.levelLittle,
    FoodLevel.dangerous => l10n.levelDangerous,
    null => l10n.levelAsk,
  };
}

/// A food answer as a tag: Safe sage, A little yellow, Dangerous ink with
/// a warning icon (no red), Ask your vet neutral.
class FoodLevelTag extends StatelessWidget {
  const FoodLevelTag({super.key, required this.level});

  final FoodLevel? level;

  @override
  Widget build(BuildContext context) {
    final label = foodLevelText(context, level);
    return switch (level) {
      FoodLevel.safe => AppTag(label, tone: AppTagTone.sage),
      FoodLevel.aLittle => AppTag(label, tone: AppTagTone.yellow),
      FoodLevel.dangerous => AppTag(
        label,
        tone: AppTagTone.ink,
        icon: Icons.warning_amber_rounded,
      ),
      null => AppTag(label),
    };
  }
}

/// The name of [animal] on the foods page's menu chip.
String safetyAnimalText(BuildContext context, SafetyAnimal animal) {
  final l10n = context.safetyL10n;
  return switch (animal) {
    SafetyAnimal.dog => l10n.animalDog,
    SafetyAnimal.cat => l10n.animalCat,
    SafetyAnimal.bird => l10n.animalBird,
    SafetyAnimal.other => l10n.animalOther,
  };
}

/// The language code of the screen ('he' or 'en').
String safetyLanguageOf(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'he' ? 'he' : 'en';
