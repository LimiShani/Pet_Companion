import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/share/health_pdf.dart';
import 'package:pet_companion/features/health/share/issue_report.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/presentation/health_format.dart';
import 'package:pet_companion/services/pet_records/data/fake_health_repository.dart';
import 'package:pet_companion/services/pet_records/data/issue_models.dart';
import 'package:pet_companion/services/pet_records/state/health_issues.dart';

import '../health/health_test_helpers.dart';

// The PDF of one followed problem: built by the records' PDF builder, in
// English and in Hebrew (right to left, the embedded fonts), with each
// entry's photos as thumbnails.

const pet = Pet(id: 'kelly', name: 'Kelly');

Future<ByteData> fromDisk(String path) async => ByteData.sublistView(File(path).readAsBytesSync());

final readable = PdfHealthPdfBuilder(compress: false, loadFont: fromDisk);

Future<(IssueDigest, Map<String, Uint8List>)> sample() async {
  final repo = FakeHealthRepository(latency: Duration.zero, now: () => fixedNow, seedIssue: true);
  final digests = digestIssues(
    await repo.fetchIssues('kelly'),
    await repo.fetchObservations('kelly'),
    await repo.fetchEntryPhotos('kelly'),
  );
  final digest = digests.single;
  return (digest, {for (final p in digest.photos) p.id: await repo.entryPhotoBytes(p)});
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('the English report: the problem, its state and every entry with its photos', () async {
    final (digest, photos) = await sample();
    final report = buildIssueReport(
      format: HealthFormat.forLocale(englishLocale),
      pet: pet,
      digest: digest,
      now: fixedNow,
      photos: photos,
      ownerName: 'Alex',
    );
    expect(report.title, 'Kelly: Limping, right front leg');
    expect(report.prepared, 'Prepared on 10.06.25 by Alex with PetLoop');
    expect(report.fileName, 'kelly-limping-right-front-leg.pdf');
    expect(report.facts, [
      ('Started on', '03.06.25'),
      ('Status', 'Ongoing'),
      ('Body area', 'Right front leg'),
      ('Entries', '4 entries'),
    ]);
    expect(report.recordsTitle, 'Entries');
    expect(report.columns, ['Date', 'How it was', 'What', 'Notes']);
    expect(report.records, hasLength(4));
    final first = report.records.first;
    expect(first.date, '03.06.25 · 19:10');
    expect(first.kind, 'Less than usual');
    expect(first.title, 'Mobility');
    expect(first.details, 'Limping on the right front leg after the park');
    expect(report.records.map((r) => r.photos.length), [0, 1, 1, 0]);
    expect(report.rightToLeft, isFalse);

    // Resolved, and a photo that could not be loaded is left out.
    final resolved = buildIssueReport(
      format: HealthFormat.forLocale(englishLocale),
      pet: pet,
      digest: IssueDigest(
        issue: digest.issue.withResolved(DateTime(2025, 6, 10)),
        entries: digest.entries,
        photos: digest.photos,
      ),
      now: fixedNow,
    );
    expect(resolved.facts[1], ('Status', 'Resolved on 10.06.25'));
    expect(resolved.records.every((r) => r.photos.isEmpty), isTrue);
    expect(resolved.prepared, 'Prepared on 10.06.25 with PetLoop');
  });

  test('a problem without entries has no table', () {
    final report = buildIssueReport(
      format: HealthFormat.forLocale(englishLocale),
      pet: pet,
      digest: IssueDigest(
        issue: HealthIssue(id: 'i', petId: 'kelly', title: 'Itchy ear', startedOn: DateTime(2025, 6, 9)),
      ),
      now: fixedNow,
    );
    expect(report.records, isEmpty);
    expect(report.recordsTitle, '');
    expect(report.facts.last, ('Entries', 'No entries yet'));
    expect(report.facts.map((f) => f.$1), isNot(contains('Body area')));
  });

  test('the Hebrew report reads right to left, keeping what was typed in one piece', () async {
    final (digest, photos) = await sample();
    final he = lookupHealthL10n(hebrewLocale);
    final report = buildIssueReport(
      format: HealthFormat.forLocale(hebrewLocale),
      pet: pet,
      digest: digest,
      now: fixedNow,
      photos: photos,
    );
    expect(report.rightToLeft, isTrue);
    expect(report.title, he.reportRecordTitle('Kelly', 'Limping, right front leg'));
    expect(report.columns, ['תאריך', 'איך היה', 'מה', 'הערות']);
    final facts = {for (final f in report.facts) f.$1: stripBidiMarks(f.$2)};
    expect(facts['תאריך התחלה'], '03.06.25');
    expect(facts['מצב'], 'עדיין נמשך');
    expect(facts['איפה בגוף'], 'Right front leg');
    expect(facts['רישומים'], '4 רישומים');
    expect(report.records.first.kind, 'פחות מהרגיל');
    expect(stripBidiMarks(report.records.first.details), 'Limping on the right front leg after the park');
  });

  testWidgets('builds as text in the embedded fonts with the photos, in both languages', (tester) async {
    final (digest, photos) = (await tester.runAsync(sample))!;
    for (final locale in [englishLocale, hebrewLocale]) {
      final report = buildIssueReport(
        format: HealthFormat.forLocale(locale),
        pet: pet,
        digest: digest,
        now: fixedNow,
        photos: photos,
      );
      final bytes = (await tester.runAsync(() => readable.build(report)))!;
      final pdf = latin1.decode(bytes);
      expect(pdf, startsWith('%PDF-'));
      expect(pdf, contains(locale == hebrewLocale ? '/BaseFont/Fredoka' : '/BaseFont/Nunito'));
      // The thumbnails, drawn from the photos (each with its mask).
      expect(RegExp('/Subtype/Image').allMatches(pdf).length, greaterThanOrEqualTo(2));
    }
  });

  testWidgets('text the fonts cannot draw falls back to pictured pages, photos included', (tester) async {
    final (digest, photos) = (await tester.runAsync(sample))!;
    final report = buildIssueReport(
      format: HealthFormat.forLocale(englishLocale),
      pet: pet,
      digest: IssueDigest(
        issue: digest.issue.copyWith(title: 'Limping 🐾'),
        entries: digest.entries,
        photos: digest.photos,
      ),
      now: fixedNow,
      photos: photos,
    );
    final bytes = (await tester.runAsync(() => readable.build(report)))!;
    final pdf = latin1.decode(bytes);
    expect(pdf, startsWith('%PDF-'));
    expect(pdf, isNot(contains('/BaseFont/Nunito')));
    expect(pdf, contains('/Subtype/Image'));
  });

  testWidgets('a photo the PDF cannot read is left out, not a failure', (tester) async {
    final (digest, _) = (await tester.runAsync(sample))!;
    final report = buildIssueReport(
      format: HealthFormat.forLocale(englishLocale),
      pet: pet,
      digest: digest,
      now: fixedNow,
      photos: {for (final p in digest.photos) p.id: Uint8List.fromList([1, 2, 3])},
    );
    final bytes = (await tester.runAsync(() => readable.build(report)))!;
    expect(latin1.decode(bytes), isNot(contains('/Subtype/Image')));
  });
}
