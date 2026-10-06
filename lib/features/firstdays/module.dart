import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../state/pets_provider.dart';
import 'firstdays.dart';

final firstDaysModule = FeatureModule(
  id: 'firstdays',
  home: [
    FeatureContribution(
      id: 'arrival-checklist',
      capability: 'firstdays.view',
      order: 40,
      builder: (_, _) => Consumer(
        builder: (c, ref, _) =>
            FirstDaysHomeCard(pet: ref.watch(selectedPetProvider)),
      ),
    ),
  ],
  slots: {
    'arrival-question': FeatureSlot(
      capability: 'firstdays.edit',
      build: (c, r) => ArrivalQuestion(
        controller: r.value<ArrivalController>('controller')!,
      ),
    ),
    'firstdays-profile': FeatureSlot(
      capability: 'firstdays.view',
      build: (c, r) => FirstDaysProfileEntry(pet: requestPet(c, r)),
    ),
  },
);
