import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import '../../widgets/pet_selector.dart';
import '../pets/pets.dart';
import 'data/health_models.dart';
import 'emergency/emergency_button.dart';
import 'insights/quick_log_sheet.dart';
import 'records/record_detail_screen.dart';
import 'records/record_form_screen.dart';
import 'schedule/medicine_form_screen.dart';
import 'schedule/record_dose_sheet.dart';
import 'sections/history_section.dart';
import 'sections/insights_section.dart';
import 'sections/overview_section.dart';
import 'sections/schedule_section.dart';
import 'share/share_actions.dart';
import 'state/health_keeper.dart';
import 'state/health_providers.dart';
import 'widgets/health_widgets.dart';

/// The Pets feature's full-size reminder card, shown on the Overview right
/// under the pet summary while an essential is missing. It draws nothing,
/// and takes no space, for a pet whose essentials are all answered.
Widget? petReminderSlot(Pet pet) => PetReminderCard(
  petId: pet.id,
  margin: const EdgeInsets.only(top: AppSpacing.cardGap),
);

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
    // On the Overview the Quick log is the first quick action instead.
    final quickLogButton = value != null && section != HealthSection.overview;
    final l10n = context.healthL10n;

    return HealthKeeper(
      petId: pet.id,
      keep: HealthKeep.everything,
      child: Scaffold(
        floatingActionButton: quickLogButton
            ? FloatingActionButton.extended(
                key: const Key('quick-log-button'),
                heroTag: null,
                onPressed: () => showQuickLog(context, pet),
                icon: const AppIcon(Icons.add_rounded),
                label: Text(l10n.quickLog),
              )
            : null,
        body: Column(
          children: [
            CoralHeader(
              title: l10n.tabTitle,
              actions: [EmergencyButton(petId: pet.id)],
              bottom: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PetSelector(),
                  const SizedBox(height: 12),
                  CoralSegmentedControl(
                    labels: [
                      for (final s in HealthSection.values)
                        switch (s) {
                          HealthSection.overview => l10n.sectionOverview,
                          HealthSection.schedule => l10n.sectionSchedule,
                          HealthSection.history => l10n.sectionHistory,
                          HealthSection.insights => l10n.sectionInsights,
                        },
                    ],
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
                              title: l10n.loadFailedHealth(pet.name),
                              error: data.error!,
                              onRetry: () => refreshHealth(ref, pet.id),
                            )
                          : const HealthLoading(),
                    )
                  : SingleChildScrollView(
                      key: PageStorageKey('health-${pet.id}-${section.name}'),
                      // Room for the Quick log button under the last item.
                      padding: EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.screen,
                        16,
                        AppSpacing.screen,
                        quickLogButton ? AppSpacing.fabClearance + MediaQuery.paddingOf(context).bottom : 24,
                      ),
                      child: _section(context, pet, section, value),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, Pet pet, HealthSection section, PetHealthData data) {
    return switch (section) {
      HealthSection.overview => OverviewSection(
        pet: pet,
        data: data,
        reminder: petReminderSlot(pet),
        actions: OverviewActions(
          onQuickLog: () => showQuickLog(context, pet),
          onAddRecord: () => openRecordForm(context, pet),
          onShare: () => shareHealthSummary(context, pet),
          onAddDocument: () => openRecordForm(context, pet, kind: RecordKind.document),
          onAddAppointment: () => openRecordForm(context, pet, kind: RecordKind.checkup, planned: true),
          onAddMedicine: () => openMedicineForm(context, pet),
          onRecordDose: (entry) => showRecordDoseSheet(context, pet, entry: entry),
          onOpenRecord: (record) => openRecordDetail(context, pet, record),
          onOpenMedicine: (medication) => openMedicineForm(context, pet, medication: medication),
        ),
      ),
      HealthSection.schedule => ScheduleSection(pet: pet, data: data),
      HealthSection.history => HistorySection(pet: pet, data: data),
      HealthSection.insights => InsightsSection(pet: pet, data: data),
    };
  }
}
