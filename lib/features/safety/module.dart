import '../../platform/feature_module.dart';

/// The safety tools of the Emergency sheet (`docs/safety.md`): "Is it
/// urgent?", "Can they eat this?" and Lost mode. Their content and data
/// live in `lib/services/safety/`; the sheet (Health) shows a tool's row
/// once this module answers its action (`safety-urgent`, `safety-food`,
/// `lost-mode`, `lost-alert`) for the account.
///
/// The pages come with the approved designs; until then the module
/// registers nothing and the sheet's Lost mode row opens the lost-pet card.
const safetyModule = FeatureModule(id: 'safety');
