import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../pets/pets.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../share/share_actions.dart';
import '../state/health_keeper.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'emergency_contacts.dart';
import 'emergency_kit_screen.dart';
import 'emergency_sheet.dart';
import 'health_profile_form.dart';
import 'lost_pet_card_screen.dart';
import 'vets_screen.dart';

/// Opens the full Emergency card of [petId] over the whole app. Nothing
/// opens for an unknown pet id.
Future<void> openEmergencyCard(BuildContext context, String petId) {
  for (final pet in ProviderScope.containerOf(context, listen: false).read(petsProvider)) {
    if (pet.id == petId) return pushHealthPage<void>(context, EmergencyCardScreen(pet: pet));
  }
  assert(false, 'openEmergencyCard: no pet with id "$petId" in petsProvider');
  return Future.value();
}

/// What a vet needs at a glance: identification, allergies, conditions,
/// active medicines and who to call, with Call / Message / Map buttons.
class EmergencyCardScreen extends ConsumerWidget {
  const EmergencyCardScreen({super.key, required this.pet, this.onShare});

  final Pet pet;

  /// Replaces what "Share summary" does. By default it hands the pet's
  /// health summary, as a PDF, to the phone's share sheet.
  final void Function(BuildContext context, HealthSummary summary)? onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(healthSummaryProvider(pet.id));
    final contacts = ref.watch(emergencyContactsProvider(pet.id));
    final onShare = this.onShare ?? (BuildContext context, HealthSummary _) => shareHealthSummary(context, pet);
    final l10n = context.healthL10n;

    return HealthKeeper(
      petId: pet.id,
      keep: HealthKeep.everything,
      child: Scaffold(
        body: Column(
          children: [
            CoralHeader(
              title: l10n.emergencyCardTitle,
              showBack: true,
              actions: [
                if (summary.hasValue)
                  CoralHeaderAction(
                    icon: Icons.ios_share_rounded,
                    tooltip: l10n.shareSummary,
                    onPressed: () => onShare(context, summary.value!),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screen,
                  16,
                  AppSpacing.screen,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: summary.when(
                  loading: () => const HealthLoading(),
                  error: (error, _) => HealthLoadError(
                    title: l10n.loadFailedEmergencyCard,
                    error: error,
                    onRetry: () => ref.invalidate(healthSummaryProvider(pet.id)),
                  ),
                  data: (data) => _Card(pet: pet, summary: data, contacts: contacts.value, onShare: onShare),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.pet, required this.summary, required this.contacts, required this.onShare});

  final Pet pet;
  final HealthSummary summary;
  final EmergencyContacts? contacts;
  final void Function(BuildContext context, HealthSummary summary) onShare;

  @override
  Widget build(BuildContext context) {
    final profile = summary.profile;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final grams = SpeciesSettings.of(pet.species).weightInGrams;
    final line = format.dots([
      format.petLine(pet),
      if (summary.weightKg != null) format.weight(summary.weightKg!, grams: grams),
    ]);
    final facts = <(String, String)>[
      if (profile.allergiesAnswered)
        (l10n.allergies, profile.allergies.isEmpty ? l10n.noneKnown : format.commas(profile.allergies)),
      if (profile.conditionsAnswered)
        (l10n.conditions, profile.conditions.isEmpty ? l10n.noneKnown : format.commas(profile.conditions)),
      if (summary.medications.isNotEmpty)
        (
          l10n.activeMedicines,
          [
            for (final m in summary.medications) format.dots([m.displayName, format.instructions(m)]),
          ].join('\n'),
        ),
      if (profile.notes.trim().isNotEmpty) (l10n.notes, profile.notes.trim()),
    ];
    final chip = profile.microchip.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthCard(
          color: AppColors.yellow,
          radius: AppSpacing.cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.coral, width: 3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExcludeSemantics(child: PetAvatar(pet: pet, size: 50)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TypedText(pet.name, style: AppText.petName.copyWith(fontSize: 20)),
                        Text(line, style: AppText.secondary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(l10n.microchip, style: AppText.label.copyWith(color: AppColors.brown)),
              Text(
                // A microchip number reads left to right on every screen.
                chip.isNotEmpty
                    ? format.ltrInLine(chip)
                    : profile.notChipped
                    ? l10n.notChipped
                    : l10n.notAddedYet,
                style: AppText.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (facts.isEmpty)
          HealthPromptCard(
            icon: Icons.fact_check_rounded,
            title: l10n.allergiesAndConditions,
            message: l10n.nothingSavedTapProfile,
            onTap: () => HealthProfileScreen.open(context, pet),
          )
        else
          HealthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < facts.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  LabeledValue(facts[i].$1, facts[i].$2),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (contacts != null) EmergencyContactList(pet: pet, contacts: contacts!) else const HealthLoading(),
        EmergencyKitRow(pet: pet),
        const SizedBox(height: 10),
        LostPetButton(pet: pet),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('share-summary'),
          onPressed: () => onShare(context, summary),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: const AppIcon(Icons.ios_share_rounded),
          label: Text(l10n.shareSummary),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            HealthLink(
              l10n.petsVets(pet.name),
              icon: Icons.medical_services_rounded,
              onPressed: () => VetsScreen.open(context, pet),
            ),
            HealthLink(
              l10n.editHealthProfile,
              icon: Icons.edit_rounded,
              onPressed: () => HealthProfileScreen.open(context, pet),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FinePrint(l10n.emergencyCardFinePrint),
      ],
    );
  }
}
