import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import 'findvet.dart';

final findVetModule = FeatureModule(
  id: 'findvet',
  actions: {
    'directory-review': FeatureAction.task(
      capability: 'findvet.admin',
      open: (c, r) => openDirectoryReview(c),
    ),
    'find-vet': FeatureAction.task(
      capability: 'findvet.search',
      open: (c, r) => openFindVet(c, mode: r.value<VetSearchMode>('mode')),
    ),
  },
);
