/// Find a vet: emergency care and long term care nearby, in one import:
///
/// ```dart
/// import 'package:pet_companion/features/findvet/findvet.dart';
/// ```
///
/// - `openFindVet(context)` opens the choice; `mode:` opens one path
///   directly (the Emergency sheet and the sign-in screen open
///   `VetSearchMode.emergency`). It needs no account, form or pet.
/// - `openDirectoryReview(context)` is the reviewers' page; show its entry
///   only while `vetIsAdminProvider` is true.
///
/// Countries are modules (`regions/`); the design, the evidence rules and
/// the backend contract are in `docs/find_a_vet.md`.
library;

export 'admin/directory_review_screen.dart'
    show DirectoryReviewScreen, openDirectoryReview;
export '../../services/findvet/data/fake_vet_finder_repository.dart';
export '../../services/findvet/data/location_service.dart';
export '../../services/findvet/data/vet_admin_repository.dart';
export '../../services/findvet/data/vet_finder_repository.dart';
export '../../services/findvet/data/vet_launcher.dart';
export '../../services/findvet/data/vet_models.dart';
export 'find_vet_screen.dart' show FindVetScreen, openFindVet;
export '../../services/findvet/regions/regions.dart';
export '../../services/findvet/state/find_vet_providers.dart';
export 'widgets/area_picker.dart' show AreaBar, AreaPicker;
export 'widgets/vet_result_card.dart' show VetResultCard;
