import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../presentation/pet_icon_bank.dart';
import '../../../presentation/pet_words.dart';

/// The six kinds of animal, three to a row, each with its default icon:
/// step 1 of the add-a-pet flow and the profile's "Name and kind" sheet.
/// Each tile is keyed `kind-<species>`.
class PetKindPicker extends StatelessWidget {
  const PetKindPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PetSpecies selected;
  final ValueChanged<PetSpecies>? onSelected;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 2 * gap) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final species in PetSpecies.values)
              SizedBox(
                width: width.floorToDouble(),
                child: Semantics(
                  button: true,
                  selected: species == selected,
                  child: Material(
                    color: species == selected
                        ? AppColors.yellow
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('kind-${species.name}'),
                      onTap: onSelected == null
                          ? null
                          : () => onSelected!(species),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 9),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(
                              child: PetIconImage(
                                PetIcon.defaultFor(species),
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                petSpeciesText(context.petsL10n, species),
                                style: AppText.secondary.copyWith(
                                  fontWeight: species == selected
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
