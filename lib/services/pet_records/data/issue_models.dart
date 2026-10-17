import 'health_models.dart';

/// Whether a followed problem is still going on. [dbValue] is
/// `health_issues.status`.
enum IssueStatus {
  open('open'),
  resolved('resolved');

  const IssueStatus(this.dbValue);

  final String dbValue;

  static IssueStatus fromDb(String? value) => value == resolved.dbValue
      ? IssueStatus.resolved
      : IssueStatus.open;
}

/// A problem the owner follows over days or weeks ("Limping, right front
/// leg"). Its entries are Quick log [Observation]s whose `issueId` is this
/// [id]; an entry's photos are [HealthDocument]s with an `observationId`.
///
/// What the owner noticed, in their words: never a diagnosis.
class HealthIssue {
  const HealthIssue({
    required this.id,
    required this.petId,
    required this.title,
    required this.startedOn,
    this.bodyArea = '',
    this.status = IssueStatus.open,
    this.resolvedOn,
    this.createdBy,
  });

  /// At most this many new problems per pet per day (the server's limit).
  static const maxNewPerDay = 20;

  /// At most this many photos on one entry (the server's limit).
  static const maxPhotosPerEntry = 4;

  /// The longest title and body area the server keeps.
  static const maxTitleLength = 80;
  static const maxBodyAreaLength = 60;

  /// Empty until the repository has stored the problem.
  final String id;
  final String petId;
  final String title;

  /// Where on the body, in the owner's words; empty when not given.
  final String bodyArea;

  /// The day it started (a local calendar day).
  final DateTime startedOn;
  final IssueStatus status;

  /// The day it was marked resolved, while [status] is resolved.
  final DateTime? resolvedOn;

  /// The account that started following it, set by the server; `null`
  /// until stored and in the sample data.
  final String? createdBy;

  bool get isNew => id.isEmpty;
  bool get isOpen => status == IssueStatus.open;

  HealthIssue copyWith({
    String? id,
    String? title,
    String? bodyArea,
    DateTime? startedOn,
  }) => HealthIssue(
    id: id ?? this.id,
    petId: petId,
    title: title ?? this.title,
    bodyArea: bodyArea ?? this.bodyArea,
    startedOn: startedOn ?? this.startedOn,
    status: status,
    resolvedOn: resolvedOn,
    createdBy: createdBy,
  );

  /// The same problem resolved on [day] (never before it started), or open
  /// again when [day] is `null`.
  HealthIssue withResolved(DateTime? day) => HealthIssue(
    id: id,
    petId: petId,
    title: title,
    bodyArea: bodyArea,
    startedOn: startedOn,
    status: day == null ? IssueStatus.open : IssueStatus.resolved,
    resolvedOn: day == null
        ? null
        : (dateOnly(day).isBefore(startedOn) ? startedOn : dateOnly(day)),
    createdBy: createdBy,
  );

  /// Why this problem cannot be saved, or `null` when it can.
  HealthFailure? get failure {
    final name = title.trim();
    if (name.isEmpty || name.length > maxTitleLength) {
      return HealthFailure.invalid;
    }
    if (bodyArea.trim().length > maxBodyAreaLength) return HealthFailure.invalid;
    final resolved = resolvedOn;
    if (resolved != null && dateOnly(resolved).isBefore(dateOnly(startedOn))) {
      return HealthFailure.invalid;
    }
    return null;
  }
}

/// A photo of an entry: only these types (no PDF, no video).
const entryPhotoMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

/// Why [file] cannot be added to an entry, or `null` when it can.
HealthFailure? entryPhotoFailure(PickedFile file) {
  if (!entryPhotoMimeTypes.contains(file.mimeType)) {
    return HealthFailure.photoType;
  }
  return file.failure;
}
