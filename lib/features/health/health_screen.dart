import '../../access/feature_gate.dart';
import '../../access/access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../platform/feature_ui.dart' show AddTab;
import '../../state/pets_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/add_sheet.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import '../../widgets/pet_switcher.dart';
import 'emergency/emergency_button.dart';
import 'records/record_detail_screen.dart';
import 'schedule/record_dose_sheet.dart';
import 'sections/overview_section.dart';
import 'sections/records_section.dart';
import 'sections/schedule_section.dart';
import 'share/share_actions.dart';
import '../../services/pet_records/state/health_keeper.dart';
import '../../services/pet_records/state/health_providers.dart';
import '../../presentation/health_widgets.dart';

/// The Health tab: a personal health organiser for the selected pet, in
/// three sections (Overview, Schedule, Records). The Emergency button, the
/// pet switcher and the tab's one "+" (its Add sheet: Quick log, a record,
/// an appointment, a medicine, a routine) are on every one of them.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability:
        'health.records.view|health.schedule.view|health.emergency.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(selectedPetProvider);
    final visible = [
      HealthSection.overview,
      if (ref.watch(capabilityProvider('health.schedule.view')))
        HealthSection.schedule,
      if (ref.watch(capabilityProvider('health.records.view')))
        HealthSection.records,
    ];
    final requested = ref.watch(healthSectionProvider);
    final section = visible.contains(requested) ? requested : visible.first;
    final data = ref.watch(petHealthDataProvider(pet.id));
    final value = data.value;
    // Once the pet's health has loaded (the forms build on it).
    final plus = value != null && AddFab.available(ref, AddTab.health);
    final l10n = context.healthL10n;

    return HealthKeeper(
      petId: pet.id,
      keep: HealthKeep.everything,
      child: Scaffold(
        floatingActionButton: plus
            ? AddFab(tab: AddTab.health, title: l10n.addToHealth, petId: pet.id)
            : null,
        body: Column(
          children: [
            CoralHeader(
              title: l10n.tabTitle,
              // The pet switcher and the Emergency pill fill the row; the
              // avatar (the You page) is on every other tab.
              showAccount: false,
              actions: [
                const PetSwitcher(),
                const SizedBox(width: 8),
                EmergencyButton(petId: pet.id),
              ],
              bottom: CoralSegmentedControl(
                labels: [
                  for (final s in visible)
                    switch (s) {
                      HealthSection.overview => l10n.sectionOverview,
                      HealthSection.schedule => l10n.sectionSchedule,
                      HealthSection.records => l10n.recordsSection,
                    },
                ],
                selectedIndex: visible.indexOf(section),
                onChanged: (index) =>
                    ref.read(healthSectionProvider.notifier).show(visible[index]),
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
                      // Room for the "+" under the last item.
                      padding: EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.screen,
                        16,
                        AppSpacing.screen,
                        plus
                            ? AppSpacing.fabClearance +
                                  MediaQuery.paddingOf(context).bottom
                            : 24,
                      ),
                      child: _section(context, ref, pet, section, value),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    WidgetRef ref,
    Pet pet,
    HealthSection section,
    PetHealthData data,
  ) {
    return switch (section) {
      HealthSection.overview => OverviewSection(
        pet: pet,
        data: data,
        actions: OverviewActions(
          onAdd: AddFab.available(ref, AddTab.health)
              ? () => showAddSheet(
                  context,
                  tab: AddTab.health,
                  title: context.healthL10n.addToHealth,
                  petId: pet.id,
                )
              : null,
          onRecordDose: (entry) =>
              showRecordDoseSheet(context, pet, entry: entry),
          onOpenRecord: (record) => openRecordDetail(context, pet, record),
        ),
      ),
      HealthSection.schedule => ScheduleSection(pet: pet, data: data),
      HealthSection.records => RecordsSection(
        pet: pet,
        data: data,
        onShare: ref.watch(capabilityProvider('health.records.export'))
            ? () => shareHealthSummary(context, pet)
            : null,
      ),
    };
  }
}
