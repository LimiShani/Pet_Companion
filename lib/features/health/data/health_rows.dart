import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import 'health_models.dart';

/// Conversions between the Health models and the rows of the tables in
/// `supabase/migrations/0002_health.sql`. Kept apart from the repository
/// so they can be tested without a backend.
///
/// Column conventions: `timestamptz` travels as UTC ISO text, a `date` as
/// `yyyy-MM-dd` (a local calendar day), a `time` as `HH:mm:ss`.
typedef Row = Map<String, dynamic>;

String? _text(Object? value) => value as String?;
String _textOr(Object? value, [String fallback = '']) => (value as String?) ?? fallback;

/// A `timestamptz` column as a local [DateTime].
DateTime instantFromDb(Object? value) => DateTime.parse(value as String).toLocal();
DateTime? instantFromDbOrNull(Object? value) => value == null ? null : instantFromDb(value);
String instantToDb(DateTime at) => at.toUtc().toIso8601String();

/// A `date` column as local midnight of that day.
DateTime dayFromDb(Object? value) {
  final parts = (value as String).substring(0, 10).split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

DateTime? dayFromDbOrNull(Object? value) => value == null ? null : dayFromDb(value);

String dayToDb(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// A `time` column.
TimeOfDay timeFromDb(Object? value) {
  final parts = (value as String).split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

TimeOfDay? timeFromDbOrNull(Object? value) => value == null ? null : timeFromDb(value);

String timeToDb(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

List<String> _texts(Object? value) => [for (final item in (value as List?) ?? const []) item as String];

// ------------------------------------------------------------ health_events

HealthRecord recordFromRow(Row row) => HealthRecord(
  id: row['id'] as String,
  petId: row['pet_id'] as String,
  kind: RecordKind.fromDb(_text(row['kind'])),
  title: _textOr(row['title']),
  notes: _textOr(row['notes']),
  scheduledAt: instantFromDb(row['scheduled_at']),
  doneAt: instantFromDbOrNull(row['done_at']),
  clinic: _textOr(row['clinic']),
  productName: _textOr(row['product_name']),
  nextDueOn: dayFromDbOrNull(row['next_due_on']),
  followUpOf: _text(row['follow_up_of']),
  costAmount: (row['cost_amount'] as num?)?.toDouble(),
  costCurrency: _textOr(row['cost_currency'], AppConfig.defaultCurrency),
);

/// The columns of a record. `id` and `owner_id` are left to the caller:
/// the database generates the first and defaults the second.
Row recordToRow(HealthRecord record) => {
  'pet_id': record.petId,
  'kind': record.kind.dbValue,
  'title': record.title,
  'notes': record.notes.isEmpty ? null : record.notes,
  'scheduled_at': instantToDb(record.scheduledAt),
  'done_at': record.doneAt == null ? null : instantToDb(record.doneAt!),
  'clinic': record.clinic.isEmpty ? null : record.clinic,
  'product_name': record.productName.isEmpty ? null : record.productName,
  'next_due_on': record.nextDueOn == null ? null : dayToDb(record.nextDueOn!),
  'follow_up_of': record.followUpOf,
  // Columns of 0006_health_phase1.sql.
  'cost_amount': record.costAmount,
  'cost_currency': record.costAmount == null ? null : record.costCurrency,
};

// --------------------------------------------------------- health_documents

HealthDocument documentFromRow(Row row) => HealthDocument(
  id: row['id'] as String,
  petId: row['pet_id'] as String,
  recordId: row['record_id'] as String,
  fileName: _textOr(row['file_name']),
  mimeType: _textOr(row['mime_type']),
  sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
  storagePath: _textOr(row['storage_path']),
);

// --------------------------------------------------------------------- vets

Vet vetFromRow(Row row) => Vet(
  id: row['id'] as String,
  name: _textOr(row['name']),
  phone: _textOr(row['phone']),
  onWhatsApp: (row['on_whatsapp'] as bool?) ?? false,
  address: _textOr(row['address']),
  openingHours: _textOr(row['opening_hours']),
  notes: _textOr(row['notes']),
);

Row vetToRow(Vet vet) => {
  'name': vet.name,
  'phone': vet.phone,
  'on_whatsapp': vet.onWhatsApp,
  'address': vet.address,
  'opening_hours': vet.openingHours,
  'notes': vet.notes,
};

// ---------------------------------------------------------- health_profiles

HealthProfile profileFromRow(Row row) => HealthProfile(
  petId: row['pet_id'] as String,
  microchip: _textOr(row['microchip']),
  notChipped: (row['not_chipped'] as bool?) ?? false,
  allergies: _texts(row['allergies']),
  allergiesNoneKnown: (row['allergies_none_known'] as bool?) ?? false,
  conditions: _texts(row['conditions']),
  conditionsNoneKnown: (row['conditions_none_known'] as bool?) ?? false,
  contactName: _textOr(row['contact_name']),
  contactPhone: _textOr(row['contact_phone']),
  notes: _textOr(row['notes']),
  regularVetId: _text(row['regular_vet_id']),
  emergencyVetId: _text(row['emergency_vet_id']),
);

Row profileToRow(HealthProfile profile) => {
  'pet_id': profile.petId,
  'microchip': profile.microchip,
  'not_chipped': profile.notChipped,
  'allergies': profile.allergies,
  'allergies_none_known': profile.allergiesNoneKnown,
  'conditions': profile.conditions,
  'conditions_none_known': profile.conditionsNoneKnown,
  'contact_name': profile.contactName,
  'contact_phone': profile.contactPhone,
  'notes': profile.notes,
  'regular_vet_id': profile.regularVetId,
  'emergency_vet_id': profile.emergencyVetId,
};

// -------------------------------------------------------------- medications

Medication medicationFromRow(Row row) => Medication(
  id: row['id'] as String,
  petId: row['pet_id'] as String,
  name: _textOr(row['name']),
  strength: _textOr(row['strength']),
  dose: _textOr(row['dose']),
  route: _textOr(row['route']),
  frequency: _textOr(row['frequency']),
  startsOn: dayFromDbOrNull(row['starts_on']),
  endsOn: dayFromDbOrNull(row['ends_on']),
  prescribedBy: _textOr(row['prescribed_by']),
  instructions: _textOr(row['instructions']),
);

Row medicationToRow(Medication medication) => {
  'pet_id': medication.petId,
  'name': medication.name,
  'strength': medication.strength,
  'dose': medication.dose,
  'route': medication.route,
  'frequency': medication.frequency,
  'starts_on': medication.startsOn == null ? null : dayToDb(medication.startsOn!),
  'ends_on': medication.endsOn == null ? null : dayToDb(medication.endsOn!),
  'prescribed_by': medication.prescribedBy,
  'instructions': medication.instructions,
};

// ---------------------------------------------------------- care_plan_items

CarePlanItem planItemFromRow(Row row) => CarePlanItem(
  id: row['id'] as String,
  petId: row['pet_id'] as String,
  kind: CareKind.fromDb(_text(row['kind'])),
  title: _textOr(row['title']),
  time: timeFromDb(row['time_of_day']),
  days: {for (final day in (row['days_of_week'] as List?) ?? const []) (day as num).toInt()},
  medicationId: _text(row['medication_id']),
  startsOn: dayFromDbOrNull(row['starts_on']),
  endsOn: dayFromDbOrNull(row['ends_on']),
  active: (row['active'] as bool?) ?? true,
);

Row planItemToRow(CarePlanItem item) => {
  'pet_id': item.petId,
  'kind': item.kind.dbValue,
  'title': item.title,
  'time_of_day': timeToDb(item.time),
  'days_of_week': item.days.toList()..sort(),
  'medication_id': item.medicationId,
  'starts_on': item.startsOn == null ? null : dayToDb(item.startsOn!),
  'ends_on': item.endsOn == null ? null : dayToDb(item.endsOn!),
  'active': item.active,
};

// ---------------------------------------------------------------- care_logs

CareLog logFromRow(Row row) => CareLog(
  id: row['id'] as String,
  petId: row['pet_id'] as String,
  planItemId: _text(row['plan_item_id']),
  medicationId: _text(row['medication_id']),
  title: _textOr(row['title']),
  dueOn: dayFromDb(row['due_on']),
  dueTime: timeFromDbOrNull(row['due_time']),
  status: CareLogStatus.fromDb(_text(row['status'])),
  doneAt: instantFromDbOrNull(row['done_at']),
  note: _textOr(row['note']),
  loggedByName: _textOr(row['logged_by_name']),
  loggedAt: instantFromDb(row['logged_at']),
);

Row logToRow(CareLog log) => {
  'pet_id': log.petId,
  'plan_item_id': log.planItemId,
  'medication_id': log.medicationId,
  'title': log.title,
  'due_on': dayToDb(log.dueOn),
  'due_time': log.dueTime == null ? null : timeToDb(log.dueTime!),
  'status': log.status.dbValue,
  'done_at': log.doneAt == null ? null : instantToDb(log.doneAt!),
  'note': log.note,
  'logged_by_name': log.loggedByName,
  'logged_at': instantToDb(log.loggedAt),
};

// ------------------------------------------------------ health_observations

Observation observationFromRow(Row row) => Observation(
  id: row['id'] as String,
  petId: row['pet_id'] as String,
  category: _textOr(row['category'], 'other'),
  level: ObservationLevel.fromDb(_text(row['level'])),
  value: (row['value'] as num?)?.toDouble(),
  note: _textOr(row['note']),
  observedAt: instantFromDb(row['observed_at']),
);

Row observationToRow(Observation observation) => {
  'pet_id': observation.petId,
  'category': observation.category,
  'level': observation.level?.dbValue,
  'value': observation.value,
  // A weight is always stored in kilograms, whatever unit is displayed.
  'unit': observation.isWeight ? 'kg' : null,
  'note': observation.note,
  'observed_at': instantToDb(observation.observedAt),
};

// ------------------------------------------------------ emergency_kit_items

/// `null` for an item this version of the app does not know.
KitCheck? kitCheckFromRow(Row row) {
  final item = KitItem.fromDb(_text(row['item']));
  if (item == null) return null;
  return KitCheck(
    petId: row['pet_id'] as String,
    item: item,
    checkedAt: instantFromDbOrNull(row['checked_at']),
    note: _textOr(row['note']),
  );
}

Row kitCheckToRow(KitCheck check) => {
  'pet_id': check.petId,
  'item': check.item.dbValue,
  'checked_at': check.checkedAt == null ? null : instantToDb(check.checkedAt!),
  'note': check.note,
};

// ----------------------------------------------------------- lost_pet_cards

LostPetCard lostCardFromRow(Row row) => LostPetCard(
  petId: row['pet_id'] as String,
  description: _textOr(row['description']),
  area: _textOr(row['area']),
  lastSeenAt: instantFromDbOrNull(row['last_seen_at']),
  phone: _textOr(row['phone']),
  extra: _textOr(row['extra']),
  language: LostCardLanguage.fromCode(_text(row['language'])),
  foundAt: instantFromDbOrNull(row['found_at']),
);

Row lostCardToRow(LostPetCard card) => {
  'pet_id': card.petId,
  'description': card.description,
  'area': card.area,
  'last_seen_at': card.lastSeenAt == null ? null : instantToDb(card.lastSeenAt!),
  'phone': card.phone,
  'extra': card.extra,
  'language': card.language.code,
  'found_at': card.foundAt == null ? null : instantToDb(card.foundAt!),
};
