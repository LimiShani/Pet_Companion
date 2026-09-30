import 'package:flutter/material.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
import '../icons/pet_icon_bank.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_widgets.dart';

/// The icon bank: the animals that suit the pet's kind first, then all the
/// others, and four backgrounds. Pops with the chosen [PetIconChoice].
class IconBankScreen extends StatefulWidget {
  const IconBankScreen({super.key, required this.species, this.initial});

  final PetSpecies species;

  /// The pet's current icon, preselected.
  final PetIconChoice? initial;

  @override
  State<IconBankScreen> createState() => _IconBankScreenState();
}

class _IconBankScreenState extends State<IconBankScreen> {
  late PetIcon _icon = widget.initial?.icon ?? PetIcon.defaultFor(widget.species);
  late PetIconBackground _background = widget.initial?.background ?? PetIconBackground.yellow;

  static String _forKind(PetSpecies species) => switch (species) {
        PetSpecies.dog => 'For a dog',
        PetSpecies.cat => 'For a cat',
        PetSpecies.bird => 'For a bird',
        PetSpecies.rabbit => 'For a rabbit',
        PetSpecies.reptile => 'For a reptile',
        PetSpecies.other => 'Suggested',
      };

  @override
  Widget build(BuildContext context) {
    final own = PetIcon.forSpecies(widget.species);
    final others = [
      for (final icon in PetIcon.values)
        if (!own.contains(icon)) icon,
    ];

    Widget bank(List<PetIcon> icons) => Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final icon in icons)
              _Selectable(
                key: Key('icon-${icon.key}'),
                label: icon.label,
                selected: icon == _icon,
                onTap: () => setState(() => _icon = icon),
                child: PetPictureCircle(
                  size: 72,
                  icon: PetIconChoice(icon, icon == _icon ? _background : PetIconBackground.yellow),
                ),
              ),
          ],
        );

    return PetsPage(
      title: 'Pick an icon',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PetPictureCircle(
              size: 96,
              icon: PetIconChoice(_icon, _background),
              borderColor: AppColors.coral,
              borderWidth: 4,
            ),
          ),
          PetsLabel(_forKind(widget.species)),
          bank(own),
          const PetsLabel('All animals'),
          bank(others),
          const PetsLabel('Background'),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final background in PetIconBackground.values)
                _Selectable(
                  key: Key('icon-bg-${background.name}'),
                  label: '${background.label} background',
                  selected: background == _background,
                  onTap: () => setState(() => _background = background),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: background.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: kPetsLine, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Use this icon',
            onPressed: () => Navigator.of(context).pop(PetIconChoice(_icon, _background)),
          ),
        ],
      ),
    );
  }
}

/// A round choice with a ring around it while it is selected.
class _Selectable extends StatelessWidget {
  const _Selectable({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? AppColors.coralDark : Colors.transparent, width: 3),
          ),
          child: ExcludeSemantics(child: child),
        ),
      ),
    );
  }
}
