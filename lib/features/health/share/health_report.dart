import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../services/pet_records/state/health_providers.dart';

/// One line of a report's record table.
class HealthReportRow {
  const HealthReportRow({
    required this.date,
    required this.kind,
    required this.title,
    this.details = '',
  });

  final String date;
  final String kind;
  final String title;

  /// Product, clinic, next due date and notes, joined.
  final String details;
}

/// What goes on a shared PDF: plain text only, so it can be checked in
/// tests and drawn by any `HealthPdfBuilder`.
///
/// The text is in the language of the screen the report was made from.
/// In Hebrew a name, a number or anything typed is kept in one piece with
/// invisible direction marks (see `HealthFormat`); the PDF builder reads
/// them to put every piece in its place.
class HealthReport {
  const HealthReport({
    required this.title,
    required this.subtitle,
    required this.prepared,
    required this.fileName,
    this.facts = const [],
    this.recordsTitle = '',
    this.records = const [],
    this.footer = '',
    this.columns = const [],
    this.rightToLeft = false,
  });

  /// "Kelly: health summary".
  final String title;

  /// "Dog · Mix · 13.6 years · 23 kg".
  final String subtitle;

  /// "Prepared on 10.06.25 by Alex with PetLoop".
  final String prepared;

  /// "kelly-health-summary.pdf".
  final String fileName;

  /// Label and value pairs: microchip, allergies, conditions, medicines,
  /// the vets and the emergency contact. Only what the owner has entered.
  final List<(String, String)> facts;

  /// Heading of the record table ("Recent records"); the table is left out
  /// when [records] is empty.
  final String recordsTitle;
  final List<HealthReportRow> records;
  final String footer;

  /// The headings of the record table's four columns (date, kind, record,
  /// details); no heading row when empty.
  final List<String> columns;

  /// The report reads right to left (Hebrew).
  final bool rightToLeft;

  /// Every piece of text on the report, in reading order.
  List<String> get allText => [
    title,
    subtitle,
    prepared,
    for (final fact in facts) ...[fact.$1, fact.$2],
    recordsTitle,
    ...columns,
    for (final row in records) ...[row.date, row.kind, row.title, row.details],
    footer,
  ];
}

/// How many history records a summary carries.
const summaryRecordLimit = 25;

String _vetLine(HealthFormat format, Vet vet) => format.dots([
  vet.name,
  if (vet.hasPhone) format.ltrInLine(vet.phone.trim()),
  if (vet.hasAddress) vet.address.trim(),
]);

String _slug(String text) {
  final slug = text
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'pet' : slug;
}

/// A record as one table line, in the words of [format].
HealthReportRow reportRow(HealthFormat format, HealthRecord record) {
  final l10n = format.l10n;
  final details = format.dots([
    record.productName.trim(),
    record.clinic.trim(),
    if (record.nextDueOn != null) l10n.nextDue(format.date(record.nextDueOn!)),
    if (!record.isDone) l10n.reportPlanned,
    record.notes.trim(),
  ]);
  return HealthReportRow(
    date: format.date(record.when),
    kind: l10n.recordKind(record.kind),
    title: format.typed(record.title),
    details: details,
  );
}

/// The report of a pet, in the language of [format]: its details,
/// allergies and conditions, active medicines and vets, then a table of
/// [records] (the chosen ones, or the recent history). [single]: the
/// report is about one record only.
HealthReport buildHealthReport({
  required HealthFormat format,
  required HealthSummary summary,
  required List<HealthRecord> records,
  required DateTime now,
  bool single = false,
}) {
  final l10n = format.l10n;
  final pet = summary.pet;
  final profile = summary.profile;
  final grams = SpeciesSettings.of(pet.species).weightInGrams;
  final weight = summary.weightKg;
  final chip = profile.microchip.trim();
  final contact = format.dots([
    profile.contactName.trim(),
    if (profile.contactPhone.trim().isNotEmpty)
      format.ltrInLine(profile.contactPhone.trim()),
  ]);

  final facts = <(String, String)>[
    if (chip.isNotEmpty)
      (l10n.microchip, format.ltrInLine(chip))
    else if (profile.notChipped)
      (l10n.microchip, l10n.notChipped),
    if (profile.allergiesAnswered)
      (
        l10n.allergies,
        profile.allergies.isEmpty
            ? l10n.noneKnown
            : format.semicolons(profile.allergies),
      ),
    if (profile.conditionsAnswered)
      (
        l10n.conditions,
        profile.conditions.isEmpty
            ? l10n.noneKnown
            : format.semicolons(profile.conditions),
      ),
    if (summary.medications.isNotEmpty)
      (
        l10n.activeMedicines,
        [
          for (final m in summary.medications)
            format.instructions(m).isEmpty
                ? format.typed(m.displayName)
                : l10n.reportMedicineLine(
                    m.displayName,
                    format.instructions(m),
                  ),
        ].join('\n'),
      ),
    if (summary.regularVet != null)
      (l10n.vetRoleRegular, _vetLine(format, summary.regularVet!)),
    if (summary.emergencyVet != null)
      (l10n.reportEmergencyVet, _vetLine(format, summary.emergencyVet!)),
    if (contact.isNotEmpty) (l10n.emergencyContact, contact),
    if (profile.notes.trim().isNotEmpty)
      (l10n.notes, format.typed(profile.notes.trim())),
  ];

  final owner = summary.ownerName.trim();
  final one = single && records.length == 1 ? records.first : null;
  return HealthReport(
    title: one == null
        ? l10n.reportSummaryTitle(pet.name)
        : l10n.reportRecordTitle(pet.name, one.title),
    subtitle: format.dots([
      format.petLine(pet, now: now),
      if (weight != null) format.weight(weight, grams: grams),
    ]),
    prepared: owner.isEmpty
        ? l10n.reportPrepared(format.date(now))
        : l10n.reportPreparedBy(format.date(now), owner),
    fileName: one == null
        ? '${_slug(pet.name)}-health-summary.pdf'
        : '${_slug(pet.name)}-${_slug(one.title)}.pdf',
    facts: facts,
    recordsTitle: records.isEmpty
        ? ''
        : one != null
        ? l10n.record
        : single
        ? l10n.reportRecords
        : l10n.reportRecentRecords,
    records: [for (final record in records) reportRow(format, record)],
    footer: l10n.reportFooter,
    columns: [l10n.fieldDate, l10n.reportColumnKind, l10n.record, l10n.details],
    rightToLeft: format.isRtl,
  );
}
