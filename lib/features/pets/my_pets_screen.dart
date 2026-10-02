import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import 'data/pets_repository_provider.dart';
import 'pet_actions.dart';
import 'pet_words.dart';
import 'profile/remove_pet.dart';
import 'state/pet_completeness.dart';
import 'widgets/pet_avatar.dart';
import 'widgets/pet_essentials_keeper.dart';
import 'widgets/pets_widgets.dart';

/// All the owner's pets at a glance: who is complete, who has gaps, "Add a
/// pet", and the archived ones with "Restore".
class MyPetsScreen extends ConsumerWidget {
  const MyPetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider);
    final archived = ref.watch(archivedPetsProvider);
    final now = ref.watch(petsClockProvider)();

    return PetsPage(
      title: context.petsL10n.myPetsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final pet in pets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PetRow(pet: pet, now: now),
            ),
          PetsRow(
            dashed: true,
            leading: const PetsDisc(Icons.add_rounded),
            title: context.petsL10n.addPetTitle,
            onTap: () => openAddPet(context),
          ),
          if (archived.isNotEmpty) ...[
            PetsLabel(context.petsL10n.archived, topGap: 26),
            for (final pet in archived)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ArchivedRow(pet: pet),
              ),
            const SizedBox(height: 4),
            PetsFinePrint(context.petsL10n.archivedNote),
          ],
        ],
      ),
    );
  }
}

class _PetRow extends ConsumerWidget {
  const _PetRow({required this.pet, required this.now});

  final Pet pet;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(petCompletenessProvider(pet.id));

    return PetsCard(
      key: Key('my-pet-${pet.id}'),
      onTap: () => openPetProfile(context, pet.id, fromMyPets: true),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
      // Stays up to date while a profile covers this page.
      child: PetEssentialsKeeper(petId: pet.id, child: _content(context.petsL10n, info)),
    );
  }

  Widget _content(PetsL10n l10n, PetCompleteness info) {
    final missing = info.missing.length;
    return Row(
      children: [
        PetAvatar(pet: pet, size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pet.name, style: AppText.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(petSummaryLine(l10n, pet, now: now), style: AppText.secondary.copyWith(color: AppColors.brown)),
              if (info.isKnown) ...[
                const SizedBox(height: 5),
                if (info.isComplete)
                  PetsTag(l10n.complete, tone: TagTone.green, icon: Icons.check_rounded)
                else
                  PetsTag(l10n.essentialsToAdd(missing), tone: TagTone.yellow),
              ],
            ],
          ),
        ),
        const AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
      ],
    );
  }
}

class _ArchivedRow extends ConsumerStatefulWidget {
  const _ArchivedRow({required this.pet});

  final Pet pet;

  @override
  ConsumerState<_ArchivedRow> createState() => _ArchivedRowState();
}

class _ArchivedRowState extends ConsumerState<_ArchivedRow> {
  bool _busy = false;

  Future<void> _restore() async {
    final pet = widget.pet;
    setState(() => _busy = true);
    try {
      await restorePet(ProviderScope.containerOf(context, listen: false), pet);
      if (mounted) showPetsSnack(context, context.petsL10n.petIsBack(pet.name));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showPetsSnack(context, petsErrorOf(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final when = pet.archivedAt;
    final l10n = context.petsL10n;
    final kind = petSpeciesText(l10n, pet.species);
    return PetsRow(
      leading: PetAvatar(pet: pet, size: 56, dimmed: true),
      title: pet.name,
      subtitle: when == null ? kind : l10n.archivedRow(kind, AppFormat.of(context).date(when)),
      trailing: PillButton(
        l10n.restore,
        key: Key('restore-${pet.id}'),
        outlined: true,
        onPressed: _busy ? null : _restore,
      ),
    );
  }
}
