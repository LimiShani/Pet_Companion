export 'contracts.dart';
export 'issue_models.dart';
import 'contracts.dart';

/// Compatibility aggregate. Each service can be replaced independently
/// through its own repository provider.
abstract class HealthRepository
    implements
        MedicalRecordsRepository,
        EmergencyRepository,
        ScheduleRepository,
        ObservationsRepository,
        HealthIssuesRepository {}
