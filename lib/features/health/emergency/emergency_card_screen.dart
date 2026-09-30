import '../../pets/pets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../share/share_actions.dart';
import '../state/health_keeper.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'emergency_contacts.dart';
import 'emergency_sheet.dart';
import 'health_profile_form.dart';
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

    return HealthKeeper(
      petId: pet.id,
      keep: HealthKeep.everything,
      child: Scaffold(
        body: Column(
          children: [
            CoralHeader(
              title: 'Emergency card',
              showBack: true,
              actions: [
                if (summary.hasValue)
                  CoralHeaderAction(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Share summary',
                    onPressed: () => onShare(context, summary.value!),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  16,
                  AppSpacing.screen,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: summary.when(
                  loading: () => const HealthLoading(),
                  error: (error, _) => HealthLoadError(
                    what: 'the Emergency card',
                    message: healthErrorMessage(error),
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
    final grams = SpeciesSettings.of(pet.species).weightInGrams;
    final line = [
      petLine(pet),
      if (summary.weightKg != null) formatWeight(summary.weightKg!, grams: grams),
    ].join(' · ');
    final facts = <(String, String)>[
      if (profile.allergiesAnswered)
        ('Allergies', profile.allergies.isEmpty ? 'None known' : profile.allergies.join(', ')),
      if (profile.conditionsAnswered)
        ('Conditions', profile.conditions.isEmpty ? 'None known' : profile.conditions.join(', ')),
      if (summary.medications.isNotEmpty)
        (
          'Active medicines',
          summary.medications
              .map((m) => m.instructionLine.isEmpty ? m.displayName : '${m.displayName} · ${m.instructionLine}')
              .join('\n'),
        ),
      if (profile.notes.trim().isNotEmpty) ('Notes', profile.notes.trim()),
    ];

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
                        Text(pet.name, style: AppText.petName.copyWith(fontSize: 20)),
                        Text(line, style: AppText.secondary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Microchip', style: AppText.label.copyWith(color: AppColors.brown)),
              Text(
                profile.microchip.trim().isNotEmpty
                    ? profile.microchip.trim()
                    : profile.notChipped
                    ? 'Not chipped'
                    : 'Not added yet',
                style: AppText.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (facts.isEmpty)
          HealthPromptCard(
            icon: Icons.fact_check_rounded,
            title: 'Allergies and conditions',
            message: 'Nothing saved yet. Tap to fill in the health profile.',
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
        OutlinedButton.icon(
          key: const Key('share-summary'),
          onPressed: () => onShare(context, summary),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Share summary'),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            HealthLink(
              "${pet.name}'s vets",
              icon: Icons.medical_services_rounded,
              onPressed: () => VetsScreen.open(context, pet),
            ),
            HealthLink(
              'Edit health profile',
              icon: Icons.edit_rounded,
              onPressed: () => HealthProfileScreen.open(context, pet),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const FinePrint('You make the call or send the message yourself. $kSafetyLine'),
      ],
    );
  }
}
