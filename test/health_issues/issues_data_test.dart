import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/services/pet_records/data/fake_health_repository.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/data/health_rows.dart';
import 'package:pet_companion/services/pet_records/data/issue_models.dart';
import 'package:pet_companion/services/pet_records/state/health_issues.dart';
import 'package:pet_companion/services/pet_records/state/health_providers.dart';

import '../health/health_test_helpers.dart';

// Following a problem, below the screens: the sample problem, the fake
// repository's rules (they mirror 0033_health_issues.sql), the rows sent to
// Supabase, and the controllers.

const kelly = 'kelly';

FakeHealthRepository withIssue() =>
    FakeHealthRepository(latency: Duration.zero, now: () => fixedNow, seedIssue: true);

PickedFile photo([String mime = 'image/png', int size = 10]) =>
    PickedFile(name: 'paw.png', mimeType: mime, bytes: Uint8List(size)..[0] = 1);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the sample problem', () {
    test('Kelly follows one open problem with four entries and two photos', () async {
      final repo = withIssue();
      final issues = await repo.fetchIssues(kelly);
      expect(issues, hasLength(1));
      final limp = issues.single;
      expect(limp.title, 'Limping, right front leg');
      expect(limp.startedOn, DateTime(2025, 6, 3));
      expect(limp.isOpen, isTrue);

      final entries = await repo.fetchIssueEntries(kelly, limp.id);
      expect(entries, hasLength(4));
      expect(entries.first.observedAt.isBefore(entries.last.observedAt), isTrue);
      expect(entries.every((e) => e.category == 'mobility'), isTrue);
      final photos = await repo.fetchEntryPhotos(kelly);
      expect(photos, hasLength(2));
      expect(photos.every((p) => p.observationId != null && p.recordId.isEmpty), isTrue);

      // The entries are ordinary journal entries; the photos are not
      // record documents.
      expect((await repo.fetchObservations(kelly)).where((o) => o.issueId == limp.id), hasLength(4));
      expect((await repo.fetchDocuments(kelly)).where((d) => d.observationId != null), isEmpty);
      expect(await repo.fetchIssues('soya'), isEmpty);
    });

    test('is not in the default sample data, so other journals keep their entries', () async {
      final repo = fakeHealth();
      expect(await repo.fetchIssues(kelly), isEmpty);
      expect(await repo.fetchObservations(kelly), hasLength(9));
      expect(await repo.fetchEntryPhotos(kelly), isEmpty);
    });
  });

  group('the repository', () {
    test('starts, renames, resolves, reopens and deletes a problem', () async {
      final repo = fakeHealth();
      final started = await repo.saveIssue(
        HealthIssue(id: '', petId: kelly, title: '  Itchy ear ', bodyArea: ' ', startedOn: DateTime(2025, 6, 8, 15)),
      );
      expect(started.id, isNotEmpty);
      expect(started.title, 'Itchy ear');
      expect(started.bodyArea, '');
      expect(started.startedOn, DateTime(2025, 6, 8));

      final renamed = await repo.saveIssue(started.copyWith(title: 'Itchy left ear', bodyArea: 'Left ear'));
      expect(renamed.title, 'Itchy left ear');
      expect(renamed.bodyArea, 'Left ear');

      final resolved = await repo.saveIssue(renamed.withResolved(DateTime(2025, 6, 10, 9)));
      expect(resolved.status, IssueStatus.resolved);
      expect(resolved.resolvedOn, DateTime(2025, 6, 10));
      // Never before it started.
      expect(renamed.withResolved(DateTime(2025, 6, 1)).resolvedOn, DateTime(2025, 6, 8));

      final reopened = await repo.saveIssue(resolved.withResolved(null));
      expect(reopened.isOpen, isTrue);
      expect(reopened.resolvedOn, isNull);

      await repo.deleteIssue(reopened.id);
      expect(await repo.fetchIssues(kelly), isEmpty);
    });

    test('refuses a problem without a title, and the 21st of a day', () async {
      final repo = fakeHealth();
      HealthIssue issue(String title) => HealthIssue(id: '', petId: kelly, title: title, startedOn: fixedNow);
      await expectLater(
        repo.saveIssue(issue('  ')),
        throwsA(isA<HealthException>().having((e) => e.failure, 'failure', HealthFailure.invalid)),
      );
      await expectLater(repo.saveIssue(issue('x' * 81)), throwsA(isA<HealthException>()));
      for (var i = 0; i < HealthIssue.maxNewPerDay; i++) {
        await repo.saveIssue(issue('Problem $i'));
      }
      await expectLater(
        repo.saveIssue(issue('One too many')),
        throwsA(isA<HealthException>().having((e) => e.failure, 'failure', HealthFailure.tooManyIssues)),
      );
      // Another pet has its own count.
      await repo.saveIssue(HealthIssue(id: '', petId: 'soya', title: 'Sneezing', startedOn: fixedNow));
    });

    test('deleting a problem keeps its entries and their photos, without the link', () async {
      final repo = withIssue();
      final limp = (await repo.fetchIssues(kelly)).single;
      await repo.deleteIssue(limp.id);
      final entries = (await repo.fetchObservations(kelly)).where((o) => o.id.startsWith('o-limp'));
      expect(entries, hasLength(4));
      expect(entries.every((e) => e.issueId == null), isTrue);
      expect(await repo.fetchEntryPhotos(kelly), hasLength(2));
    });

    test('links an entry, keeps the link when the entry is saved, and unlinks it', () async {
      final repo = withIssue();
      final limp = (await repo.fetchIssues(kelly)).single;
      final energy = (await repo.fetchObservations(kelly)).firstWhere((o) => o.id == 'o-energy');

      final linked = await repo.linkEntry(energy, limp.id);
      expect(linked.issueId, limp.id);
      expect(await repo.fetchIssueEntries(kelly, limp.id), hasLength(5));

      // The Quick log saves an edit without the link: it stays.
      final edited = await repo.saveObservation(
        Observation(id: energy.id, petId: kelly, category: 'energy', level: ObservationLevel.less, note: 'Tired', observedAt: energy.observedAt),
      );
      expect(edited.issueId, limp.id);

      final unlinked = await repo.linkEntry(edited, null);
      expect(unlinked.issueId, isNull);
      expect(await repo.fetchIssueEntries(kelly, limp.id), hasLength(4));

      // Only a problem of the same pet.
      final soyaIssue = await repo.saveIssue(HealthIssue(id: '', petId: 'soya', title: 'Sneezing', startedOn: fixedNow));
      await expectLater(repo.linkEntry(energy, soyaIssue.id), throwsA(isA<HealthException>()));
      // A new entry can be saved straight into a problem.
      final added = await repo.saveObservation(
        Observation(id: '', petId: kelly, category: 'mobility', level: ObservationLevel.usual, observedAt: fixedNow, issueId: limp.id),
      );
      expect(added.issueId, limp.id);
    });

    test('an entry takes up to four photos, photos only', () async {
      final repo = withIssue();
      const entry = 'o-limp-1';
      await expectLater(
        repo.addEntryPhoto(petId: kelly, observationId: entry, file: photo('application/pdf')),
        throwsA(isA<HealthException>().having((e) => e.failure, 'failure', HealthFailure.photoType)),
      );
      await expectLater(
        repo.addEntryPhoto(petId: kelly, observationId: entry, file: photo('image/jpeg', PickedFile.maxBytes + 1)),
        throwsA(isA<HealthException>().having((e) => e.failure, 'failure', HealthFailure.fileTooLarge)),
      );
      for (var i = 0; i < HealthIssue.maxPhotosPerEntry; i++) {
        final added = await repo.addEntryPhoto(petId: kelly, observationId: entry, file: photo(i.isEven ? 'image/webp' : 'image/jpeg'));
        expect(added.observationId, entry);
        expect(await repo.entryPhotoBytes(added), isNotEmpty);
      }
      await expectLater(
        repo.addEntryPhoto(petId: kelly, observationId: entry, file: photo()),
        throwsA(isA<HealthException>().having((e) => e.failure, 'failure', HealthFailure.tooManyPhotos)),
      );
      await expectLater(
        repo.addEntryPhoto(petId: kelly, observationId: 'o-gone', file: photo()),
        throwsA(isA<HealthException>().having((e) => e.failure, 'failure', HealthFailure.entryGone)),
      );
    });

    test('deleting an entry removes its photos; deleting the pet removes them all', () async {
      final repo = withIssue();
      await repo.deleteObservation('o-limp-2');
      final photos = await repo.fetchEntryPhotos(kelly);
      expect(photos.map((p) => p.observationId), ['o-limp-3']);

      final removeFiles = await repo.prepareDeletingPet(kelly);
      await removeFiles();
      expect(await repo.fetchEntryPhotos(kelly), isEmpty);
      expect(await repo.fetchDocuments(kelly), isEmpty);
    });
  });

  group('the rows sent to Supabase', () {
    test('a problem', () {
      final issue = HealthIssue(
        id: '7d2b3c1e-0000-4000-8000-000000000001',
        petId: 'p',
        title: ' Limping ',
        bodyArea: '  ',
        startedOn: DateTime(2025, 6, 3),
      );
      expect(issueToRow(issue), {
        'pet_id': 'p',
        'title': 'Limping',
        'body_area': null,
        'started_on': '2025-06-03',
        'status': 'open',
        'resolved_on': null,
      });
      final row = issueToRow(issue.withResolved(DateTime(2025, 6, 9)));
      expect(row['status'], 'resolved');
      expect(row['resolved_on'], '2025-06-09');

      final read = issueFromRow({
        'id': 'i1',
        'pet_id': 'p',
        'title': 'Limping',
        'body_area': 'Right front leg',
        'started_on': '2025-06-03',
        'status': 'resolved',
        'resolved_on': '2025-06-09',
        'created_by': 'u1',
      });
      expect(read.bodyArea, 'Right front leg');
      expect(read.status, IssueStatus.resolved);
      expect(read.resolvedOn, DateTime(2025, 6, 9));
      expect(read.createdBy, 'u1');
    });

    test('an entry sends its problem only when it has one', () {
      final entry = Observation(id: '', petId: 'p', category: 'mobility', level: ObservationLevel.less, observedAt: DateTime.utc(2025, 6, 3));
      expect(observationToRow(entry).containsKey('issue_id'), isFalse);
      expect(observationToRow(entry.withIssue('i1'))['issue_id'], 'i1');
      final read = observationFromRow({
        'id': 'o1',
        'pet_id': 'p',
        'category': 'mobility',
        'level': 'less',
        'note': '',
        'observed_at': '2025-06-03T10:00:00Z',
        'issue_id': 'i1',
      });
      expect(read.issueId, 'i1');
      expect(read.copyWith(id: 'o2').issueId, 'i1');
    });

    test('a photo of an entry has no record', () {
      final doc = documentFromRow({
        'id': 'd1',
        'pet_id': 'p',
        'record_id': null,
        'observation_id': 'o1',
        'file_name': 'paw.jpg',
        'mime_type': 'image/jpeg',
        'size_bytes': 100,
        'storage_path': 'u/p/o1/x.jpg',
      });
      expect(doc.recordId, '');
      expect(doc.observationId, 'o1');
    });
  });

  group('the controllers', () {
    test('start, resolve and delete through the controller; the digest puts open ones first', () async {
      final h = HealthHarness(repository: withIssue());
      final container = h.container();
      container.listen(issueDigestsProvider(kelly), (_, _) {});
      final digests = await container.read(issueDigestsProvider(kelly).future);
      expect(digests.single.entries, hasLength(4));
      expect(digests.single.photos, hasLength(2));
      expect(digests.single.photosOf('o-limp-2'), hasLength(1));
      expect(digests.single.latest?.id, 'o-limp-4');

      final issues = container.read(healthIssuesProvider(kelly).notifier);
      final itch = await issues.save(HealthIssue(id: '', petId: kelly, title: 'Itchy ear', startedOn: DateTime(2025, 6, 9)));
      await issues.resolve(itch);
      var now = await container.read(issueDigestsProvider(kelly).future);
      expect(now.map((d) => d.issue.title), ['Limping, right front leg', 'Itchy ear']);
      expect(now.last.issue.resolvedOn, DateTime(2025, 6, 10));

      await issues.delete(now.first.issue);
      now = await container.read(issueDigestsProvider(kelly).future);
      expect(now.map((d) => d.issue.title), ['Itchy ear']);
      final journal = await container.read(observationsProvider(kelly).future);
      expect(journal.where((o) => o.id.startsWith('o-limp')).every((o) => o.issueId == null), isTrue);
    });

    test('links entries and adds photos', () async {
      final h = HealthHarness(repository: withIssue());
      final container = h.container();
      container.listen(issueDigestsProvider(kelly), (_, _) {});
      final limp = (await container.read(issueDigestsProvider(kelly).future)).single.issue;
      final energy = (await container.read(observationsProvider(kelly).future)).firstWhere((o) => o.id == 'o-energy');

      await container.read(healthIssuesProvider(kelly).notifier).link(energy, limp.id);
      final digest = (await container.read(issueDigestsProvider(kelly).future)).single;
      expect(digest.entries.map((e) => e.id), contains('o-energy'));

      final photos = container.read(entryPhotosProvider(kelly).notifier);
      await photos.add('o-energy', photo());
      expect((await container.read(issueDigestsProvider(kelly).future)).single.photos, hasLength(3));
      for (var i = 0; i < 3; i++) {
        await photos.add('o-energy', photo());
      }
      await expectLater(
        photos.add('o-energy', photo()),
        throwsA(isA<HealthException>().having((e) => e.failure, 'failure', HealthFailure.tooManyPhotos)),
      );
      final first = container.read(entryPhotosProvider(kelly)).value!.firstWhere((p) => p.observationId == 'o-energy');
      await photos.remove(first);
      expect(container.read(entryPhotosProvider(kelly)).value!.where((p) => p.observationId == 'o-energy'), hasLength(3));
    });
  });
}
