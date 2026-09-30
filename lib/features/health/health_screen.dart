import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import '../../widgets/pet_selector.dart';
import 'data/health_models.dart';
import 'emergency/emergency_button.dart';
import 'records/record_detail_screen.dart';
import 'records/record_form_screen.dart';
import 'sections/history_section.dart';
import 'sections/overview_section.dart';
import 'share/share_actions.dart';
import 'state/health_keeper.dart';
import 'state/health_providers.dart';
import 'widgets/health_widgets.dart';

/// SLOT FOR THE LEAD (integration): the Pets feature's full-size reminder
/// card, shown on the Overview right under the pet summary. Return
/// `PetReminderCard(petId: pet.id)` here once the Pets branch is merged.
/// Health itself imports nothing from the Pets folder.
Widget? petReminderSlot(Pet pet) => null;

/// The Health tab: a personal health organiser for the selected pet, in
/// four sections (Overview, Schedule, History, Insights). The Emergency
/// button, the pet switcher and the Quick log are on every one of them.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(selectedPetProvider);
    final section = ref.watch(healthSectionProvider);
    final data = ref.watch(petHealthDataProvider(pet.id));
    final value = data.value;

    return HealthKeeper(
      petId: pet.id,
      keep: HealthKeep.everything,
      child: Scaffold(
        body: Column(
          children: [
            CoralHeader(
              title: 'Health',
              actions: [EmergencyButton(petId: pet.id)],
              bottom: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PetSelector(),
                  const SizedBox(height: 12),
                  CoralSegmentedControl(
                    labels: [for (final s in HealthSection.values) s.label],
                    selectedIndex: section.index,
                    onChanged: (index) => ref.read(healthSectionProvider.notifier).show(HealthSection.values[index]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: value == null
                  ? SingleChildScrollView(
                      child: data.hasError
                          ? HealthLoadError(
                              what: "${pet.name}'s health",
                              message: healthErrorMessage(data.error!),
                              onRetry: () => refreshHealth(ref, pet.id),
                            )
                          : const HealthLoading(),
                    )
                  : SingleChildScrollView(
                      key: PageStorageKey('health-${pet.id}-${section.name}'),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 24),
                      child: _section(context, ref, pet, section, value),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, WidgetRef ref, Pet pet, HealthSection section, PetHealthData data) {
    return switch (section) {
      HealthSection.overview => OverviewSection(
        pet: pet,
        data: data,
        reminder: petReminderSlot(pet),
        actions: OverviewActions(
          onAddRecord: () => openRecordForm(context, pet),
          onShare: () => shareHealthSummary(context, pet),
          onAddDocument: () => openRecordForm(context, pet, kind: RecordKind.document),
          onAddAppointment: () => openRecordForm(context, pet, kind: RecordKind.checkup, planned: true),
          onOpenRecord: (record) => openRecordDetail(context, pet, record),
        ),
      ),
      HealthSection.history => HistorySection(pet: pet, data: data),
      // The other two sections arrive with the next milestones.
      _ => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Text('${section.label} is on its way.', textAlign: TextAlign.center, style: AppText.body),
      ),
    };
  }
}
