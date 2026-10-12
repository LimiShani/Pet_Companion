import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/unsaved_changes_guard.dart';
import '../../../presentation/pet_words.dart';
import '../../../presentation/pets_widgets.dart';
import '../widgets/kind_picker.dart';

/// The profile's "Name and kind" sheet: the name and the kind tiles of
/// step 1 of the add-a-pet flow. Saves on "Save" and closes; going back
/// with a change asks first.
Future<void> showPetNameAndKindSheet(BuildContext context, Pet pet) =>
    showPetsSheet<void>(
      context,
      PetNameAndKindSheet(key: PetNameAndKindSheet.sheetKey, pet: pet),
      // A drag would close the sheet without asking about typed changes.
      enableDrag: false,
    );

class PetNameAndKindSheet extends ConsumerStatefulWidget {
  const PetNameAndKindSheet({super.key, required this.pet});

  /// The sheet itself, for tests.
  static const sheetKey = Key('pet-name-and-kind-sheet');

  final Pet pet;

  @override
  ConsumerState<PetNameAndKindSheet> createState() =>
      _PetNameAndKindSheetState();
}

class _PetNameAndKindSheetState extends ConsumerState<PetNameAndKindSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pet.name);
  late PetSpecies _species = widget.pet.species;
  bool _saving = false;
  String? _error;

  /// Something differs from what the sheet opened with.
  bool get _dirty =>
      !_saving &&
      (_name.text.trim() != widget.pet.name.trim() ||
          _species != widget.pet.species);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The pet as it is now: something else may have changed meanwhile.
      final pet = ref.read(petsStoreProvider).byId(widget.pet.id) ?? widget.pet;
      await ref
          .read(petsStoreProvider.notifier)
          .save(pet.copyWith(name: _name.text.trim(), species: _species));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = petsErrorOf(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.petsL10n;
    return ListenableBuilder(
      listenable: _name,
      builder: (context, child) =>
          UnsavedChangesGuard(dirty: _dirty, child: child!),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PetsHeading(l10n.profileNameAndKind),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('pet-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                errorMaxLines: 3,
              ),
              validator: (text) {
                final value = text?.trim() ?? '';
                if (value.isEmpty) return l10n.nameMissing;
                if (value.length > 60) return l10n.nameTooLong(60);
                return null;
              },
            ),
            PetsLabel(l10n.kindOfAnimal),
            PetKindPicker(
              selected: _species,
              onSelected: _saving
                  ? null
                  : (species) => setState(() => _species = species),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppText.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: context.l10n.commonSave,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
