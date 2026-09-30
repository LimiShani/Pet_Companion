import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/health_rows.dart';
import 'package:pet_companion/features/health/data/supabase_health_repository.dart';

/// The Supabase repository cannot run in tests (no backend), so these check
/// the two things that can be checked without one: how models travel to and
/// from table rows, and the shape of the migration file.
void main() {
  const pet = '2b1d7c1e-7d0a-4a55-9c59-3f3a2e0c9a11';

  group('rows', () {
    test('dates, times and instants survive the trip', () {
      expect(dayToDb(DateTime(2025, 6, 9, 23, 59)), '2025-06-09');
      expect(dayFromDb('2025-06-09'), DateTime(2025, 6, 9));
      expect(timeToDb(const TimeOfDay(hour: 8, minute: 5)), '08:05:00');
      expect(timeFromDb('20:00:00'), const TimeOfDay(hour: 20, minute: 0));
      final at = DateTime(2025, 6, 10, 17, 40);
      expect(instantToDb(at), endsWith('Z'));
      expect(instantFromDb(instantToDb(at)), at);
    });

    test('a health record keeps every field', () {
      final record = HealthRecord(
        id: '',
        petId: pet,
        kind: RecordKind.vaccination,
        title: 'Rabies booster',
        notes: 'Sleepy that evening',
        scheduledAt: DateTime(2025, 3, 14, 10),
        doneAt: DateTime(2025, 3, 14, 10),
        clinic: 'Park Vet Clinic',
        productName: 'Rabies vaccine, batch A1234',
        nextDueOn: DateTime(2026, 3, 14),
        followUpOf: 'a0000000-0000-4000-8000-000000000001',
        costAmount: 180.5,
      );
      final row = recordToRow(record);
      // The database generates the id and defaults the owner.
      expect(row.containsKey('id'), isFalse);
      expect(row.containsKey('owner_id'), isFalse);
      expect(row['kind'], 'vaccination');
      expect(row['next_due_on'], '2026-03-14');

      final back = recordFromRow({...row, 'id': 'r1'});
      expect(back.id, 'r1');
      expect(back.kind, RecordKind.vaccination);
      expect(back.title, record.title);
      expect(back.notes, record.notes);
      expect(back.scheduledAt, record.scheduledAt);
      expect(back.doneAt, record.doneAt);
      expect(back.clinic, record.clinic);
      expect(back.productName, record.productName);
      expect(back.nextDueOn, record.nextDueOn);
      expect(back.followUpOf, record.followUpOf);
      expect(row['cost_amount'], 180.5);
      expect(row['cost_currency'], 'ILS');
      expect(back.costAmount, 180.5);
      expect(back.costCurrency, 'ILS');
    });

    test('a planned record and a row written before 0002 both read back', () {
      final planned = recordFromRow({
        ...recordToRow(
          HealthRecord(
            id: '',
            petId: pet,
            kind: RecordKind.checkup,
            title: 'General check',
            scheduledAt: DateTime(2025, 6, 12, 18, 20),
          ),
        ),
        'id': 'r2',
      });
      expect(planned.isDone, isFalse);
      expect(planned.notes, isEmpty);

      // Only the 0001 columns, and a kind the app does not know.
      final old = recordFromRow({
        'id': 'r3',
        'pet_id': pet,
        'kind': 'surgery',
        'title': 'Old row',
        'notes': null,
        'scheduled_at': '2024-01-05T09:00:00+00:00',
        'done_at': null,
      });
      expect(old.kind, RecordKind.other);
      expect(old.clinic, isEmpty);
      expect(old.nextDueOn, isNull);
    });

    test('a health profile keeps its honest "none" answers and its vets', () {
      const profile = HealthProfile(
        petId: pet,
        notChipped: true,
        allergies: ['Chicken', 'Grass pollen'],
        conditionsNoneKnown: true,
        contactName: 'Dana',
        contactPhone: '+972 50 555 0117',
        regularVetId: 'v1',
      );
      final back = profileFromRow(profileToRow(profile));
      expect(back.notChipped, isTrue);
      expect(back.microchipAnswered, isTrue);
      expect(back.allergies, ['Chicken', 'Grass pollen']);
      expect(back.conditionsNoneKnown, isTrue);
      expect(back.conditionsAnswered, isTrue);
      expect(back.contactName, 'Dana');
      expect(back.regularVetId, 'v1');
      expect(back.emergencyVetId, isNull);
    });

    test('a vet, a medicine and its reminder keep every field', () {
      const vet = Vet(id: '', name: 'Dr. Levi', phone: '+972 3 555 0142', onWhatsApp: true, address: '12 Park Street');
      final vetBack = vetFromRow({...vetToRow(vet), 'id': 'v1'});
      expect(vetBack.name, 'Dr. Levi');
      expect(vetBack.onWhatsApp, isTrue);
      expect(vetBack.address, '12 Park Street');

      final medication = Medication(
        id: '',
        petId: pet,
        name: 'Joint tablets',
        strength: '50 mg',
        dose: '1 tablet',
        route: 'By mouth',
        frequency: 'Twice a day with food',
        startsOn: DateTime(2025, 5, 2),
        prescribedBy: 'Dr. Levi',
      );
      final medicationBack = medicationFromRow({...medicationToRow(medication), 'id': 'm1'});
      expect(medicationBack.instructionLine, medication.instructionLine);
      expect(medicationBack.startsOn, DateTime(2025, 5, 2));
      expect(medicationBack.endsOn, isNull);

      const item = CarePlanItem(
        id: '',
        petId: pet,
        kind: CareKind.medication,
        title: 'Joint tablets',
        time: TimeOfDay(hour: 20, minute: 0),
        days: {7, 1, 3},
        medicationId: 'm1',
        active: false,
      );
      final row = planItemToRow(item);
      expect(row['days_of_week'], [1, 3, 7]);
      final itemBack = planItemFromRow({...row, 'id': 'p1'});
      expect(itemBack.time, const TimeOfDay(hour: 20, minute: 0));
      expect(itemBack.days, {1, 3, 7});
      expect(itemBack.medicationId, 'm1');
      expect(itemBack.active, isFalse);
    });

    test('a dose log and an observation keep every field', () {
      final log = CareLog(
        id: '',
        petId: pet,
        planItemId: 'p1',
        medicationId: 'm1',
        title: 'Joint tablets',
        dueOn: DateTime(2025, 6, 9),
        dueTime: const TimeOfDay(hour: 20, minute: 0),
        status: CareLogStatus.done,
        doneAt: DateTime(2025, 6, 9, 20, 10),
        note: 'Hidden in cheese',
        loggedByName: 'Alex',
        loggedAt: DateTime(2025, 6, 10, 17, 40),
      );
      final logBack = logFromRow({...logToRow(log), 'id': 'l1'});
      expect(logBack.dueOn, DateTime(2025, 6, 9));
      expect(logBack.dueTime, const TimeOfDay(hour: 20, minute: 0));
      expect(logBack.status, CareLogStatus.done);
      expect(logBack.doneAt, DateTime(2025, 6, 9, 20, 10));
      expect(logBack.note, 'Hidden in cheese');
      expect(logBack.loggedByName, 'Alex');
      expect(logBack.loggedAt, DateTime(2025, 6, 10, 17, 40));

      final weight = Observation(
        id: '',
        petId: pet,
        category: Observation.weightCategory,
        value: 0.412,
        observedAt: DateTime(2025, 6, 10, 8, 10),
      );
      final weightRow = observationToRow(weight);
      expect(weightRow['unit'], 'kg');
      expect(observationFromRow({...weightRow, 'id': 'o1'}).value, 0.412);

      final noticed = Observation(
        id: '',
        petId: pet,
        category: 'feathers',
        level: ObservationLevel.different,
        note: 'Fluffed up',
        observedAt: DateTime(2025, 6, 10, 8, 10),
      );
      final noticedBack = observationFromRow({...observationToRow(noticed), 'id': 'o2'});
      expect(noticedBack.level, ObservationLevel.different);
      expect(noticedBack.value, isNull);
      expect(noticedBack.isWeight, isFalse);
    });

    test('a document row carries where its file lives', () {
      final document = documentFromRow({
        'id': 'd1',
        'pet_id': pet,
        'record_id': 'r1',
        'storage_path': 'user/$pet/r1/file.pdf',
        'file_name': 'blood-test.pdf',
        'mime_type': 'application/pdf',
        'size_bytes': 48211,
      });
      expect(document.isPdf, isTrue);
      expect(document.sizeBytes, 48211);
      expect(document.storagePath, 'user/$pet/r1/file.pdf');
    });

    test('only database ids are treated as stored pets', () {
      expect(SupabaseHealthRepository.isStored(pet), isTrue);
      // The sample pets have no rows: empty states, not errors.
      expect(SupabaseHealthRepository.isStored('kelly'), isFalse);
      expect(SupabaseHealthRepository.isStored(''), isFalse);
    });
  });

  group('0002_health.sql', () {
    final sql = File('supabase/migrations/0002_health.sql').readAsStringSync();
    final tables = RegExp(r'create table if not exists public\.(\w+)').allMatches(sql).map((m) => m.group(1)!).toList();

    test('creates the tables of the proposal, and only adds to health_events', () {
      expect(
        tables,
        unorderedEquals([
          'vets',
          'health_profiles',
          'medications',
          'care_plan_items',
          'care_logs',
          'health_observations',
          'health_documents',
        ]),
      );
      for (final column in ['clinic', 'product_name', 'next_due_on', 'follow_up_of']) {
        expect(sql, contains('alter table public.health_events add column if not exists $column'));
      }
      for (final kind in ['preventive', 'procedure', 'document']) {
        expect(sql, contains("'$kind'"));
      }
      // Nothing of 0001 is dropped or rewritten.
      expect(sql, isNot(contains('drop table')));
      expect(sql, isNot(contains('drop column')));
      expect(sql, isNot(contains('"health_events: owner has full access" on')));
    });

    test('every table has row level security and an owner-only policy', () {
      for (final table in tables) {
        expect(sql, contains('alter table public.$table enable row level security;'), reason: table);
        expect(sql, contains('create policy "$table: owner has full access" on public.$table'), reason: table);
      }
      // Every policy is owner-only.
      final policies = RegExp(r'create policy[^;]+;').allMatches(sql).map((m) => m.group(0)!).toList();
      expect(policies, hasLength(tables.length + 1 + 4));
      for (final policy in policies) {
        expect(policy, contains('to authenticated'), reason: policy);
        expect(policy, anyOf(contains('auth.uid()'), contains('health_owns_pet')), reason: policy);
      }
      // Rows can only be written for a pet that belongs to the user.
      expect('public.health_owns_pet(pet_id)'.allMatches(sql), hasLength(7));
    });

    test('is safe to run more than once', () {
      final created = RegExp(r'create policy ("[^"]+") on ([\w.]+)').allMatches(sql);
      for (final policy in created) {
        expect(sql, contains('drop policy if exists ${policy.group(1)} on ${policy.group(2)};'));
      }
      final triggers = RegExp(r'create trigger (\w+)\s+before update on ([\w.]+)').allMatches(sql);
      expect(triggers, isNotEmpty);
      for (final trigger in triggers) {
        expect(sql, contains('drop trigger if exists ${trigger.group(1)} on ${trigger.group(2)};'));
      }
      expect(RegExp(r'create table (?!if not exists)').hasMatch(sql), isFalse);
      expect(RegExp(r'create (unique )?index (?!if not exists)').hasMatch(sql), isFalse);
      expect(RegExp(r'add column (?!if not exists)').hasMatch(sql), isFalse);
      expect(RegExp(r'create function').hasMatch(sql), isFalse, reason: 'use create or replace');
      for (final constraint in RegExp(r'add constraint (\w+)').allMatches(sql)) {
        expect(sql, contains('drop constraint if exists ${constraint.group(1)};'));
      }
    });

    test('the documents bucket is private, 5 MB, photos and PDF only', () {
      expect(sql, contains("'pet-documents', 'pet-documents', false, 5242880"));
      expect(sql, contains("array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']"));
      expect(sql, contains('on conflict (id) do update'));
      for (final action in ['read', 'upload', 'update', 'delete']) {
        expect(sql, contains('create policy "pet-documents: owner can $action" on storage.objects'));
      }
      // Each storage policy is limited to the bucket and the owner's folder.
      final storagePolicies = RegExp(r'create policy "pet-documents[^;]+;').allMatches(sql).map((m) => m.group(0)!);
      for (final policy in storagePolicies) {
        expect(policy, contains("bucket_id = 'pet-documents'"));
        expect(policy, contains('(storage.foldername(name))[1] = (select auth.uid())::text'));
      }
    });
  });

  group('0006_health_phase1.sql', () {
    final sql = File('supabase/migrations/0006_health_phase1.sql').readAsStringSync();
    final tables = RegExp(r'create table if not exists public\.(\w+)').allMatches(sql).map((m) => m.group(1)!).toList();

    test('adds the cost columns, the routine kinds and two tables, and nothing else', () {
      expect(tables, ['emergency_kit_items', 'lost_pet_cards']);
      for (final column in ['cost_amount', 'cost_currency']) {
        expect(sql, contains('alter table public.health_events add column if not exists $column'));
      }
      // The default currency is the app's.
      expect(sql, contains("cost_currency text default 'ILS'"));
      // Every kind the app can store, the old ones included.
      for (final kind in CareKind.values) {
        expect(sql, contains("'${kind.dbValue}'"), reason: kind.name);
      }
      // Purely additive: nothing removed, no bucket, no storage policy.
      expect(sql, isNot(contains('drop table')));
      expect(sql, isNot(contains('drop column')));
      expect(sql, isNot(contains('delete from')));
      expect(sql, isNot(contains('storage.')));
      // The columns of the rows the app sends exist.
      final kit = kitCheckToRow(const KitCheck(petId: pet, item: KitItem.carrier));
      final card = lostCardToRow(const LostPetCard(petId: pet));
      final kitTable = sql.substring(sql.indexOf('create table if not exists public.emergency_kit_items'));
      final cardTable = sql.substring(sql.indexOf('create table if not exists public.lost_pet_cards'));
      for (final column in kit.keys) {
        expect(kitTable, contains('\n  $column '), reason: column);
      }
      for (final column in card.keys) {
        expect(cardTable, contains('\n  $column '), reason: column);
      }
      for (final item in KitItem.values) {
        expect(item.dbValue.length, lessThanOrEqualTo(40));
      }
    });

    test('both tables have row level security and one owner-only policy', () {
      for (final table in tables) {
        expect(sql, contains('alter table public.$table enable row level security;'), reason: table);
        expect(sql, contains('create policy "$table: owner has full access" on public.$table'), reason: table);
        expect(sql, contains('grant select, insert, update, delete on public.$table to authenticated;'));
      }
      final policies = RegExp(r'create policy[^;]+;').allMatches(sql).map((m) => m.group(0)!).toList();
      expect(policies, hasLength(2));
      for (final policy in policies) {
        expect(policy, contains('to authenticated'));
        expect(policy, contains('using (owner_id = (select auth.uid()))'));
        // Rows can only be written for a pet that belongs to the user.
        expect(policy, contains('public.health_owns_pet(pet_id)'));
      }
      // Rows go with the pet and with the account.
      expect('references public.pets (id) on delete cascade'.allMatches(sql), hasLength(2));
      expect('references auth.users (id) on delete cascade'.allMatches(sql), hasLength(2));
    });

    test('is safe to run more than once, and all or nothing', () {
      for (final policy in RegExp(r'create policy ("[^"]+") on ([\w.]+)').allMatches(sql)) {
        expect(sql, contains('drop policy if exists ${policy.group(1)} on ${policy.group(2)};'));
      }
      final triggers = RegExp(r'create trigger (\w+)\s+before update on ([\w.]+)').allMatches(sql);
      expect(triggers, hasLength(2));
      for (final trigger in triggers) {
        expect(sql, contains('drop trigger if exists ${trigger.group(1)} on ${trigger.group(2)};'));
      }
      expect(RegExp(r'create table (?!if not exists)').hasMatch(sql), isFalse);
      expect(RegExp(r'create (unique )?index (?!if not exists)').hasMatch(sql), isFalse);
      expect(RegExp(r'add column (?!if not exists)').hasMatch(sql), isFalse);
      final constraints = RegExp(r'add constraint (\w+)').allMatches(sql).map((m) => m.group(1)!).toList();
      expect(constraints, ['health_events_cost_valid', 'care_plan_items_kind_check']);
      for (final constraint in constraints) {
        expect(sql, contains('drop constraint if exists $constraint;'));
      }
      expect(RegExp(r'^begin;$', multiLine: true).hasMatch(sql), isTrue);
      expect(sql.trimRight(), endsWith('commit;'));
    });
  });
}
