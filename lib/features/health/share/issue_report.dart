import 'dart:typed_data';

import '../../../models/pet.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../../../services/pet_records/state/health_issues.dart';
import 'health_report.dart';

String _slug(String text) {
  final slug = text
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug;
}

/// The PDF of one followed problem, in the language of [format]: its title,
/// the pet, when it started and its state, then every entry (date and
/// time, how it was, what, the notes) with its photos.
///
/// [photos]: the bytes of each photo by document id; a photo without bytes
/// (it could not be loaded) is left out. Built by the records' PDF builder
/// (`HealthPdfBuilder`), so Hebrew reads right to left with the same fonts.
HealthReport buildIssueReport({
  required HealthFormat format,
  required Pet pet,
  required IssueDigest digest,
  required DateTime now,
  Map<String, Uint8List> photos = const {},
  String ownerName = '',
}) {
  final l10n = format.l10n;
  final issue = digest.issue;
  final settings = SpeciesSettings.of(pet.species);
  final grams = settings.weightInGrams;
  final owner = ownerName.trim();

  HealthReportRow row(Observation entry) {
    final value = entry.value;
    final level = entry.level;
    return HealthReportRow(
      date: format.dateTime(entry.observedAt),
      kind: entry.isWeight && value != null
          ? format.weight(value, grams: grams)
          : level == null
          ? l10n.noted
          : l10n.level(level),
      title: l10n.quickLogCategory(settings.category(entry.category)),
      details: format.typed(entry.note.trim()),
      photos: [
        for (final photo in digest.photosOf(entry.id)) ?photos[photo.id],
      ],
    );
  }

  final titleSlug = _slug(issue.title);
  final petSlug = _slug(pet.name);
  return HealthReport(
    title: l10n.reportRecordTitle(pet.name, issue.title.trim()),
    subtitle: format.petLine(pet, now: now),
    prepared: owner.isEmpty
        ? l10n.reportPrepared(format.date(now))
        : l10n.reportPreparedBy(format.date(now), owner),
    fileName:
        '${petSlug.isEmpty ? 'pet' : petSlug}-${titleSlug.isEmpty ? 'problem' : titleSlug}.pdf',
    facts: [
      (l10n.issueStartedOn, format.date(issue.startedOn)),
      (
        l10n.issueStatus,
        issue.isOpen
            ? l10n.issueOngoing
            : l10n.issueResolvedOn(format.date(issue.resolvedOn!)),
      ),
      if (issue.bodyArea.trim().isNotEmpty)
        (l10n.issueBodyArea, format.typed(issue.bodyArea.trim())),
      (l10n.issueEntries, l10n.issueEntryCount(digest.entries.length)),
    ],
    recordsTitle: digest.entries.isEmpty ? '' : l10n.issueEntries,
    records: [for (final entry in digest.entries) row(entry)],
    footer: l10n.reportFooter,
    columns: [
      l10n.fieldDate,
      l10n.issueColumnLevel,
      l10n.issueColumnWhat,
      l10n.notes,
    ],
    rightToLeft: format.isRtl,
  );
}
