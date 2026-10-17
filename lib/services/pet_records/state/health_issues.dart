import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../platform/session.dart';
import '../data/health_models.dart';
import '../data/health_repository.dart';
import '../../../state/pets_provider.dart';
import 'health_providers.dart';

/// Problems followed over time (0033_health_issues.sql): the problems of a
/// pet, the photos of its Quick log entries, and what a problem's page and
/// the Overview row show. Its entries are the pet's observations
/// ([observationsProvider]) with an `issueId`.

final healthIssuesRepositoryProvider = Provider<HealthIssuesRepository>(
  (ref) => ref.watch(healthRepositoryProvider),
);

Duration? _noRetry(int retryCount, Object error) => null;

/// The problems of one pet, open and resolved.
class IssuesController extends SessionSafeAsyncNotifier<List<HealthIssue>> {
  IssuesController(this.petId);

  final String petId;

  HealthIssuesRepository get _repo {
    checkSession();
    return ref.read(healthIssuesRepositoryProvider);
  }

  @override
  Future<List<HealthIssue>> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider('health.records.view'))) {
      return const <HealthIssue>[];
    }
    return ref.watch(healthIssuesRepositoryProvider).fetchIssues(petId);
  }

  void _put(HealthIssue issue) {
    if (!ref.mounted) return;
    state = AsyncData([
      for (final i in state.value ?? const <HealthIssue>[])
        if (i.id != issue.id) i,
      issue,
    ]);
  }

  /// Starts following a problem, or changes one (title, start day, body
  /// area). Throws a [HealthException] when it is not saved.
  Future<HealthIssue> save(HealthIssue issue) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'health.records.edit');
      final problem = issue.failure;
      if (problem != null) throw HealthException.of(problem);
      final saved = await _repo.saveIssue(issue);
      _put(saved);
      return saved;
    });
  }

  /// Marks the problem resolved on [day] (today by the Health clock when
  /// not given).
  Future<HealthIssue> resolve(HealthIssue issue, {DateTime? day}) =>
      save(issue.withResolved(day ?? ref.read(healthClockProvider)()));

  /// Opens a resolved problem again.
  Future<HealthIssue> reopen(HealthIssue issue) =>
      save(issue.withResolved(null));

  /// Makes a saved entry part of the problem [issueId], or of none
  /// (`null`), and keeps the journal in step.
  Future<Observation> link(Observation entry, String? issueId) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'health.records.edit');
      final linked = await _repo.linkEntry(entry, issueId);
      if (ref.mounted) ref.invalidate(observationsProvider(petId));
      return linked;
    });
  }

  /// Stops following the problem; its entries and photos stay in the
  /// journal.
  Future<void> delete(HealthIssue issue) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'health.records.edit');
      await _repo.deleteIssue(issue.id);
      if (!ref.mounted) return;
      state = AsyncData([
        for (final i in state.value ?? const <HealthIssue>[])
          if (i.id != issue.id) i,
      ]);
      // The entries lost their link.
      ref.invalidate(observationsProvider(petId));
    });
  }
}

final healthIssuesProvider = AsyncNotifierProvider.autoDispose
    .family<IssuesController, List<HealthIssue>, String>(
      IssuesController.new,
      retry: _noRetry,
    );

/// The photos of a pet's Quick log entries.
class EntryPhotosController
    extends SessionSafeAsyncNotifier<List<HealthDocument>> {
  EntryPhotosController(this.petId);

  final String petId;

  @override
  Future<List<HealthDocument>> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider('health.records.view'))) {
      return const <HealthDocument>[];
    }
    return ref.watch(healthIssuesRepositoryProvider).fetchEntryPhotos(petId);
  }

  /// Adds a photo to the entry [observationId]. Throws a [HealthException]
  /// when the file is not a photo, too large, or one too many.
  Future<HealthDocument> add(String observationId, PickedFile file) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'health.records.edit');
      final problem = entryPhotoFailure(file);
      if (problem != null) throw HealthException.of(problem);
      final count = (state.value ?? const <HealthDocument>[])
          .where((d) => d.observationId == observationId)
          .length;
      if (count >= HealthIssue.maxPhotosPerEntry) {
        throw HealthException.of(HealthFailure.tooManyPhotos);
      }
      final photo = await ref
          .read(healthIssuesRepositoryProvider)
          .addEntryPhoto(petId: petId, observationId: observationId, file: file);
      if (ref.mounted) state = AsyncData([...?state.value, photo]);
      return photo;
    });
  }

  Future<void> remove(HealthDocument photo) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'health.records.edit');
      await ref.read(healthIssuesRepositoryProvider).deleteEntryPhoto(photo);
      if (!ref.mounted) return;
      state = AsyncData([
        for (final d in state.value ?? const <HealthDocument>[])
          if (d.id != photo.id) d,
      ]);
    });
  }
}

final entryPhotosProvider = AsyncNotifierProvider.autoDispose
    .family<EntryPhotosController, List<HealthDocument>, String>(
      EntryPhotosController.new,
      retry: _noRetry,
    );

/// A problem with what belongs to it: its entries (oldest first) and the
/// photos of those entries.
class IssueDigest {
  const IssueDigest({
    required this.issue,
    this.entries = const [],
    this.photos = const [],
  });

  final HealthIssue issue;
  final List<Observation> entries;
  final List<HealthDocument> photos;

  /// The photos of one entry.
  List<HealthDocument> photosOf(String entryId) => [
    for (final p in photos)
      if (p.observationId == entryId) p,
  ];

  /// The latest entry, or `null` while there is none.
  Observation? get latest => entries.isEmpty ? null : entries.last;
}

/// The digests of [issues]: open ones first (most recently started first),
/// then resolved ones (most recently resolved first).
List<IssueDigest> digestIssues(
  List<HealthIssue> issues,
  List<Observation> observations,
  List<HealthDocument> photos,
) {
  final digests = [
    for (final issue in issues)
      () {
        final entries = [
          for (final o in observations)
            if (o.issueId == issue.id) o,
        ]..sort((a, b) => a.observedAt.compareTo(b.observedAt));
        final ids = {for (final e in entries) e.id};
        return IssueDigest(
          issue: issue,
          entries: entries,
          photos: [
            for (final p in photos)
              if (ids.contains(p.observationId)) p,
          ],
        );
      }(),
  ];
  int order(IssueDigest a, IssueDigest b) {
    if (a.issue.isOpen != b.issue.isOpen) return a.issue.isOpen ? -1 : 1;
    final ad = a.issue.isOpen ? a.issue.startedOn : a.issue.resolvedOn!;
    final bd = b.issue.isOpen ? b.issue.startedOn : b.issue.resolvedOn!;
    return bd.compareTo(ad);
  }

  return digests..sort(order);
}

/// Every problem of a pet with its entries and photos.
final issueDigestsProvider = FutureProvider.autoDispose
    .family<List<IssueDigest>, String>((ref, petId) async {
      final issues = ref.watch(healthIssuesProvider(petId).future);
      final observations = ref.watch(observationsProvider(petId).future);
      final photos = ref.watch(entryPhotosProvider(petId).future);
      return digestIssues(await issues, await observations, await photos);
    }, retry: _noRetry);

/// The open problems, newest first, as the Overview and the Quick log
/// offer them.
List<IssueDigest> openIssues(List<IssueDigest> digests) => [
  for (final d in digests)
    if (d.issue.isOpen) d,
];

/// How long a resolved problem keeps its chip in Records.
const resolvedChipDays = 90;

/// The problems Records offers a chip for on [today]: the open ones, and
/// the ones resolved in the last [resolvedChipDays] days.
List<IssueDigest> recordsIssues(List<IssueDigest> digests, DateTime today) => [
  for (final d in digests)
    if (d.issue.isOpen ||
        daysBetween(d.issue.resolvedOn!, dateOnly(today)) <= resolvedChipDays)
      d,
];

/// The problem whose entries Records shows instead of its other views, or
/// `null`. Another pet starts without one.
class RecordsIssueController extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(selectedPetIdProvider);
    return null;
  }

  void show(String issueId) => state = issueId;
  void clear() => state = null;
}

final recordsIssueProvider = NotifierProvider<RecordsIssueController, String?>(
  RecordsIssueController.new,
);
