import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../state/health_providers.dart';

/// One line of a report's record table.
class HealthReportRow {
  const HealthReportRow({required this.date, required this.kind, required this.title, this.details = ''});

  final String date;
  final String kind;
  final String title;

  /// Product, clinic, next due date and notes, joined.
  final String details;
}

/// What goes on a shared PDF: plain text only, so it can be checked in
/// tests and drawn by any [HealthPdfBuilder].
class HealthReport {
  const HealthReport({
    required this.title,
    required this.subtitle,
    required this.prepared,
    required this.fileName,
    this.facts = const [],
    this.recordsTitle = '',
    this.records = const [],
    this.footer = reportFooter,
  });

  /// "Kelly: health summary".
  final String title;

  /// "Dog · Mix · 13.6 years · 23 kg".
  final String subtitle;

  /// "Prepared on 10.06.25 by Alex with Pet Companion".
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

  /// Every piece of text on the report, in reading order.
  List<String> get allText => [
    title,
    subtitle,
    prepared,
    for (final fact in facts) ...[fact.$1, fact.$2],
    recordsTitle,
    for (final row in records) ...[row.date, row.kind, row.title, row.details],
    footer,
  ];
}

const reportFooter =
    'Written by the owner in Pet Companion. It is a record of what was entered, not veterinary advice.';

/// How many history records a summary carries.
const summaryRecordLimit = 25;

String _vetLine(Vet vet) =>
    [vet.name, if (vet.hasPhone) vet.phone.trim(), if (vet.hasAddress) vet.address.trim()].join(' · ');

String _slug(String text) {
  final slug = text.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'pet' : slug;
}

/// A record as one table line.
HealthReportRow reportRow(HealthRecord record) {
  final details = [
    if (record.productName.trim().isNotEmpty) record.productName.trim(),
    if (record.clinic.trim().isNotEmpty) record.clinic.trim(),
    if (record.nextDueOn != null) 'Next due ${formatDate(record.nextDueOn!)}',
    if (!record.isDone) 'Planned',
    if (record.notes.trim().isNotEmpty) record.notes.trim(),
  ].join(' · ');
  return HealthReportRow(date: formatDate(record.when), kind: record.kind.label, title: record.title, details: details);
}

/// The report of a pet: its details, allergies and conditions, active
/// medicines and vets, then a table of [records] (the chosen ones, or the
/// recent history). [single]: the report is about one record only.
HealthReport buildHealthReport({
  required HealthSummary summary,
  required List<HealthRecord> records,
  required DateTime now,
  bool single = false,
}) {
  final pet = summary.pet;
  final profile = summary.profile;
  final grams = SpeciesSettings.of(pet.species).weightInGrams;
  final weight = summary.weightKg;
  final contact = [
    if (profile.contactName.trim().isNotEmpty) profile.contactName.trim(),
    if (profile.contactPhone.trim().isNotEmpty) profile.contactPhone.trim(),
  ].join(' · ');

  final facts = <(String, String)>[
    if (profile.microchip.trim().isNotEmpty)
      ('Microchip', profile.microchip.trim())
    else if (profile.notChipped)
      ('Microchip', 'Not chipped'),
    if (profile.allergiesAnswered)
      ('Allergies', profile.allergies.isEmpty ? 'None known' : profile.allergies.join('; ')),
    if (profile.conditionsAnswered)
      ('Conditions', profile.conditions.isEmpty ? 'None known' : profile.conditions.join('; ')),
    if (summary.medications.isNotEmpty)
      (
        'Active medicines',
        summary.medications
            .map((m) => m.instructionLine.isEmpty ? m.displayName : '${m.displayName}: ${m.instructionLine}')
            .join('\n'),
      ),
    if (summary.regularVet != null) ('Regular vet', _vetLine(summary.regularVet!)),
    if (summary.emergencyVet != null) ('Emergency vet', _vetLine(summary.emergencyVet!)),
    if (contact.isNotEmpty) ('Emergency contact', contact),
    if (profile.notes.trim().isNotEmpty) ('Notes', profile.notes.trim()),
  ];

  final owner = summary.ownerName.trim();
  final one = single && records.length == 1 ? records.first : null;
  return HealthReport(
    title: one == null ? '${pet.name}: health summary' : '${pet.name}: ${one.title}',
    subtitle: [petLine(pet), if (weight != null) formatWeight(weight, grams: grams)].join(' · '),
    prepared: owner.isEmpty
        ? 'Prepared on ${formatDate(now)} with Pet Companion'
        : 'Prepared on ${formatDate(now)} by $owner with Pet Companion',
    fileName: one == null ? '${_slug(pet.name)}-health-summary.pdf' : '${_slug(pet.name)}-${_slug(one.title)}.pdf',
    facts: facts,
    recordsTitle: records.isEmpty
        ? ''
        : one != null
        ? 'Record'
        : single
        ? 'Records'
        : 'Recent records',
    records: [for (final record in records) reportRow(record)],
  );
}
