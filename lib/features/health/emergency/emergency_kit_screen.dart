import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../health_strings.dart';
import '../records/pet_documents_screen.dart';
import '../state/emergency_kit.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'health_profile_form.dart';

/// Opens the emergency kit checklist of [petId] over the whole app. Nothing
/// opens for an unknown pet id.
Future<void> openEmergencyKit(BuildContext context, String petId) {
  for (final pet in ProviderScope.containerOf(context, listen: false).read(petsProvider)) {
    if (pet.id == petId) return pushHealthPage<void>(context, EmergencyKitScreen(pet: pet));
  }
  assert(false, 'openEmergencyKit: no pet with id "$petId" in petsProvider');
  return Future.value();
}

/// "3 of 6 ready", or "All 6 ready".
String kitCountLabel(HealthL10n l10n, EmergencyKit kit) => l10n.kitCount(ready: kit.ready, total: kit.total);

/// The row that leads to the kit from the emergency sheet and the
/// Emergency card: its name and how much of it is ready.
class EmergencyKitRow extends ConsumerWidget {
  const EmergencyKitRow({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(emergencyKitProvider(pet.id)).value;
    final l10n = context.healthL10n;
    return HealthCard(
      key: const Key('open-emergency-kit'),
      onTap: () => openEmergencyKit(context, pet.id),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 12, bottom: 12),
      child: Row(
        children: [
          const IconDisc(Icons.backpack_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.emergencyKit, style: AppText.cardTitle),
                Text(
                  kit == null ? l10n.kitWhatToHaveReady : kitCountLabel(l10n, kit),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
          const AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}

/// What one kit item says, for one pet. Whole sentences, in one place.
class _KitText {
  const _KitText(this.title, this.detail);

  final String title;
  final String detail;

  static _KitText of(HealthFormat format, KitItem item, Pet pet, EmergencyKit kit, HealthProfile? profile) {
    final l10n = format.l10n;
    switch (item) {
      case KitItem.carrier:
        return _KitText(switch (pet.species) {
          PetSpecies.dog => l10n.kitCarrierDog,
          PetSpecies.cat || PetSpecies.rabbit => l10n.kitCarrier,
          PetSpecies.bird => l10n.kitTravelCage,
          PetSpecies.reptile => l10n.kitTravelBox,
          PetSpecies.other => l10n.kitCarrierOrCage,
        }, l10n.kitCarrierNote);
      case KitItem.foodWater:
        return _KitText(l10n.kitFoodWater, l10n.kitFoodWaterNote);
      case KitItem.documents:
        return _KitText(
          l10n.kitDocuments,
          pet.species == PetSpecies.dog ? l10n.kitDocumentsNoteDog : l10n.kitDocumentsNote,
        );
      case KitItem.microchip:
        final number = profile?.microchip.trim() ?? '';
        return _KitText(
          l10n.kitMicrochip,
          number.isNotEmpty
              ? l10n.kitMicrochipNumber(format.ltrInLine(number))
              : (profile?.notChipped ?? false)
              ? l10n.kitMicrochipNotChipped
              : l10n.kitMicrochipNone,
        );
      case KitItem.medicines:
        return _KitText(
          l10n.kitMedicines,
          l10n.kitMedicinesNote(format.commas([for (final m in kit.medicines) m.displayName])),
        );
      case KitItem.shelterPlan:
        return _KitText(l10n.kitShelterPlan, l10n.kitShelterPlanNote(pet.name));
    }
  }
}

/// A pet's emergency kit: what to have ready for sirens, a quick move to
/// the protected room, or leaving home in a hurry. Each item is ticked and
/// remembered with its date. The owner's own list, not official guidance.
class EmergencyKitScreen extends ConsumerWidget {
  const EmergencyKitScreen({super.key, required this.pet});

  final Pet pet;

  Future<void> _toggle(BuildContext context, WidgetRef ref, KitEntry entry) async {
    try {
      await ref.read(kitChecksProvider(pet.id).notifier).setReady(entry.item, !entry.isReady);
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(emergencyKitProvider(pet.id));
    final profile = ref.watch(healthProfileProvider(pet.id)).value;
    final data = ref.watch(petHealthDataProvider(pet.id)).value;
    final value = kit.value;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);

    // The files "Documents" can open right away.
    final documents = data?.documents.length ?? 0;

    return HealthPage(
      petId: pet.id,
      title: l10n.petsEmergencyKit(pet.name),
      child: value == null
          ? kit.hasError
                ? HealthLoadError(
                    title: l10n.loadFailedKit,
                    error: kit.error!,
                    onRetry: () {
                      ref.invalidate(kitChecksProvider(pet.id));
                      ref.invalidate(carePlanProvider(pet.id));
                    },
                  )
                : const HealthLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _Summary(kit: value),
                for (final entry in value.entries) ...[
                  const SizedBox(height: 8),
                  _KitItemCard(
                    entry: entry,
                    text: _KitText.of(format, entry.item, pet, value, profile),
                    onToggle: () => _toggle(context, ref, entry),
                    link: switch (entry.item) {
                      KitItem.documents when documents > 0 => HealthLink(
                        l10n.kitDocumentsSaved(documents),
                        key: const Key('kit-open-documents'),
                        icon: Icons.chevron_right_rounded,
                        onPressed: () => PetDocumentsScreen.open(context, pet),
                      ),
                      KitItem.microchip => HealthLink(
                        l10n.healthProfile,
                        key: const Key('kit-open-profile'),
                        icon: Icons.chevron_right_rounded,
                        onPressed: () => HealthProfileScreen.open(context, pet),
                      ),
                      _ => null,
                    },
                    note: entry.item == KitItem.shelterPlan ? _PlanNote(petId: pet.id, note: entry.note) : null,
                  ),
                ],
                const SizedBox(height: 12),
                FinePrint(l10n.kitFinePrint),
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.kit});

  final EmergencyKit kit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    final label = kitCountLabel(l10n, kit);
    return HealthCard(
      key: const Key('kit-summary'),
      color: AppColors.peach,
      radius: AppSpacing.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppText.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(l10n.kitSummaryNote, style: AppText.secondary),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: kit.total == 0 ? 0 : kit.ready / kit.total,
              minHeight: 8,
              color: AppColors.coralDark,
              backgroundColor: AppColors.white.withValues(alpha: 0.6),
              semanticsLabel: l10n.emergencyKit,
              semanticsValue: label,
            ),
          ),
        ],
      ),
    );
  }
}

class _KitItemCard extends StatelessWidget {
  const _KitItemCard({required this.entry, required this.text, required this.onToggle, this.link, this.note});

  final KitEntry entry;
  final _KitText text;
  final VoidCallback onToggle;

  /// Where the facts behind the item live.
  final Widget? link;

  /// The note field of the item.
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    final checkedAt = entry.checkedAt;
    return HealthCard(
      key: ValueKey('kit-card-${entry.item.name}'),
      onTap: onToggle,
      padding: const EdgeInsetsDirectional.only(start: 4, end: 14, top: 8, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: text.title,
            child: Checkbox(
              key: ValueKey('kit-${entry.item.name}'),
              value: entry.isReady,
              onChanged: (_) => onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text.title, style: AppText.cardTitle),
                  Text(text.detail, style: AppText.secondary.copyWith(color: AppColors.brown)),
                  if (checkedAt != null)
                    Text(
                      context.healthL10n.kitTicked(HealthFormat.of(context).date(checkedAt)),
                      style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
                    ),
                  if (link != null) Align(alignment: AlignmentDirectional.centerStart, child: link),
                  if (note != null) Padding(padding: const EdgeInsetsDirectional.only(top: 8), child: note),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The owner's own words for the plan. Saved when the field is left or
/// the keyboard's "done" is pressed.
class _PlanNote extends ConsumerStatefulWidget {
  const _PlanNote({required this.petId, required this.note});

  final String petId;
  final String note;

  @override
  ConsumerState<_PlanNote> createState() => _PlanNoteState();
}

class _PlanNoteState extends ConsumerState<_PlanNote> {
  late final _text = TextEditingController(text: widget.note);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim() == widget.note) return;
    try {
      await ref.read(kitChecksProvider(widget.petId).notifier).setNote(KitItem.shelterPlan, _text.text);
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('kit-plan-note'),
      controller: _text,
      focusNode: _focus,
      minLines: 1,
      maxLines: 3,
      maxLength: 300,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(
        labelText: context.healthL10n.kitOurPlan,
        fillColor: AppColors.cream,
        counterText: '',
      ),
    );
  }
}
