import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../../../services/pets/data/pets_repository_provider.dart';
import '../../../presentation/pet_words.dart';
import '../widgets/pet_basics_fields.dart';
import '../../../presentation/pets_widgets.dart';

/// A bottom sheet with one part of the "about the pet" form: where a tap on
/// "Add Soya's weight" lands. Saves on "Save" and closes.
Future<void> showPetBasicsSheet(
  BuildContext context, {
  required Pet pet,
  required String title,
  required Set<BasicsSection> sections,
  String? note,
}) => showPetsSheet<void>(
  context,
  _BasicsSheet(pet: pet, title: title, sections: sections, note: note),
);

class _BasicsSheet extends ConsumerStatefulWidget {
  const _BasicsSheet({
    required this.pet,
    required this.title,
    required this.sections,
    this.note,
  });

  final Pet pet;
  final String title;
  final Set<BasicsSection> sections;
  final String? note;

  @override
  ConsumerState<_BasicsSheet> createState() => _BasicsSheetState();
}

class _BasicsSheetState extends ConsumerState<_BasicsSheet> {
  final _form = GlobalKey<FormState>();
  late final PetBasicsController _basics;
  bool _saving = false;
  String? _error;

  DateTime get _now => ref.read(petsClockProvider)();

  @override
  void initState() {
    super.initState();
    _basics = PetBasicsController(pet: widget.pet, now: _now);
  }

  @override
  void dispose() {
    _basics.dispose();
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
          .save(_basics.applyTo(pet, now: _now, only: widget.sections));
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
  Widget build(BuildContext context) => FeatureGate(
    capability: 'pets.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PetsHeading(widget.title),
          if (widget.note != null) ...[
            const SizedBox(height: 4),
            PetsNote(widget.note!),
          ],
          const SizedBox(height: 14),
          PetBasicsFields(
            controller: _basics,
            now: _now,
            sections: widget.sections,
            showLabels: widget.sections.length > 1,
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
    );
  }
}
