import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/primary_button.dart';
import 'icons/pet_icon_bank.dart';
import 'pet_words.dart';
import 'pets_routes.dart';
import 'widgets/pet_avatar.dart';
import 'widgets/pets_widgets.dart';

/// What a signed-in owner without any pet sees instead of the tabs: a
/// welcome that leads into the add-a-pet flow. The same page reports a
/// failed load of the pets, with "Try again".
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsStoreProvider);
    final failed = pets.status == PetsStatus.failed;
    final name = ref.watch(authControllerProvider).value?.displayName.trim() ?? '';

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Hello(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                18,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: failed
                  ? _LoadFailed(message: petsErrorOf(context, pets.cause))
                  : _FirstPet(name: name, archived: pets.archived),
            ),
          ],
        ),
      ),
    );
  }
}

/// The coral top with the app's name and three friends from the icon bank.
class _Hello extends StatelessWidget {
  const _Hello();

  static const _side = 96.0;
  static const _middle = 124.0;
  static const _overlap = 18.0;

  /// How far the pictures hang below the coral band.
  static const _drop = 56.0;

  @override
  Widget build(BuildContext context) {
    Widget friend(PetIcon icon, PetIconBackground background, double size) => PetPictureCircle(
          size: size,
          icon: PetIconChoice(icon, background),
          borderColor: AppColors.cream,
          borderWidth: 5,
        );

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _drop),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.headerRadius)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, _middle - _drop + 14),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  // The logo, announced by its name.
                  child: Semantics(
                    label: context.l10n.appName,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PetLoopMark(size: 28, tone: BrandTone.white),
                        SizedBox(width: 8),
                        PetLoopWordmark(height: 24, tone: BrandTone.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ExcludeSemantics(
          child: SizedBox(
            width: _side * 2 + _middle - _overlap * 2,
            height: _middle,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: friend(PetIcon.catTabby, PetIconBackground.peach, _side),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: friend(PetIcon.rabbitUpright, PetIconBackground.sage, _side),
                ),
                Positioned(
                  left: _side - _overlap,
                  top: 0,
                  child: friend(PetIcon.dogFloppy, PetIconBackground.yellow, _middle),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FirstPet extends ConsumerWidget {
  const _FirstPet({required this.name, required this.archived});

  final String name;
  final List<Pet> archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.petsL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PetsHeading(name.isEmpty ? l10n.welcomeTitle : l10n.welcomeTitleNamed(name), center: true, size: 24),
        const SizedBox(height: 6),
        Text(
          l10n.welcomeIntro,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.brown),
        ),
        const SizedBox(height: 20),
        PetsCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              _Why(Icons.photo_camera_rounded, l10n.welcomeWhyPhoto),
              const SizedBox(height: 10),
              _Why(Icons.call_rounded, l10n.welcomeWhyVet),
              const SizedBox(height: 10),
              _Why(Icons.fact_check_rounded, l10n.welcomeWhyHealth),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: l10n.welcomeAddFirst, onPressed: () => context.go(PetsRoutes.addPet)),
        if (archived.isNotEmpty) ...[
          PetsLabel(l10n.welcomeArchivedPets, topGap: 22),
          for (final pet in archived)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ArchivedRow(pet: pet),
            ),
        ],
        const SizedBox(height: 6),
        const _SignOut(),
      ],
    );
  }
}

class _Why extends StatelessWidget {
  const _Why(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PetsDisc(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppText.body.copyWith(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

/// An archived pet with "Restore": the way back for an owner whose only
/// visible pet was deleted.
class _ArchivedRow extends ConsumerStatefulWidget {
  const _ArchivedRow({required this.pet});

  final Pet pet;

  @override
  ConsumerState<_ArchivedRow> createState() => _ArchivedRowState();
}

class _ArchivedRowState extends ConsumerState<_ArchivedRow> {
  bool _busy = false;

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await ref.read(petsStoreProvider.notifier).save(widget.pet.withArchivedAt(null));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showPetsSnack(context, petsErrorOf(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PetsRow(
      leading: PetAvatar(pet: widget.pet, size: 44, dimmed: true),
      title: widget.pet.name,
      subtitle: petSpeciesText(context.petsL10n, widget.pet.species),
      trailing: PillButton(context.petsL10n.restore, outlined: true, onPressed: _busy ? null : _restore),
    );
  }
}

class _LoadFailed extends ConsumerWidget {
  const _LoadFailed({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PetsHeading(context.petsL10n.welcomeLoadFailed, center: true, size: 22),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.brown)),
        const SizedBox(height: 20),
        PrimaryButton(label: context.l10n.commonTryAgain, onPressed: () => ref.read(petsStoreProvider.notifier).retry()),
        const SizedBox(height: 6),
        const _SignOut(),
      ],
    );
  }
}

class _SignOut extends ConsumerWidget {
  const _SignOut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PetsTextButton(context.l10n.accountSignOut, onPressed: () => ref.read(authControllerProvider.notifier).signOut());
  }
}
