import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/pets/data/fake_pets_repository.dart';
import 'package:pet_companion/features/pets/data/pets_repository.dart';
import 'package:pet_companion/features/pets/data/supabase_pets_repository.dart';
import 'package:pet_companion/features/pets/widgets/pet_avatar.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'pets_test_helpers.dart';

Future<void> _signInDemo(ProviderContainer container) => container
    .read(authControllerProvider.notifier)
    .signIn(email: FakeAuthRepository.demoEmail, password: FakeAuthRepository.demoPassword);

Future<void> _signUp(ProviderContainer container) => container
    .read(authControllerProvider.notifier)
    .signUp(displayName: 'Limor', email: 'limor@example.com', password: 'walkies123');

/// Lets the zero-latency fakes answer.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Pet', () {
    final today = DateTime(2025, 6, 10);

    test('an exact birthday gives the age in words, and keeps counting', () {
      final pet = Pet(id: 'p', name: 'Pip', birthDate: DateTime(2022, 6, 1));
      expect(pet.hasAge, isTrue);
      expect(pet.ageLabelAt(today), '3 years');
      expect(pet.ageLabelAt(DateTime(2026, 6, 10)), '4 years');
      expect(pet.ageYearsAt(today), closeTo(3.02, 0.02));
    });

    test('an approximate age says "About"', () {
      final pet = Pet(id: 'p', name: 'Pip', birthDate: DateTime(2022, 6, 10), birthDateApprox: true);
      expect(pet.ageLabelAt(today), 'About 3 years');
    });

    test('young animals are counted in months and weeks', () {
      expect(Pet(id: 'p', name: 'Pip', birthDate: DateTime(2025, 2, 10)).ageLabelAt(today), '4 months');
      expect(Pet(id: 'p', name: 'Pip', birthDate: DateTime(2025, 5, 9)).ageLabelAt(today), '1 month');
      expect(Pet(id: 'p', name: 'Pip', birthDate: DateTime(2025, 5, 27)).ageLabelAt(today), '2 weeks');
      expect(Pet(id: 'p', name: 'Pip', birthDate: DateTime(2025, 6, 8)).ageLabelAt(today), 'Under a week');
      expect(Pet(id: 'p', name: 'Pip', birthDate: DateTime(2023, 12, 1)).ageLabelAt(today), '18 months');
    });

    test('an age given directly still works (the sample pets)', () {
      const pet = Pet(id: 'kelly', name: 'Kelly', ageYears: 13.6);
      expect(pet.hasAge, isTrue);
      expect(pet.ageYears, 13.6);
      expect(pet.ageLabel, '13.6 years');
    });

    test('no birthday and no age means the age is not known', () {
      const pet = Pet(id: 'soya', name: 'Soya');
      expect(pet.hasAge, isFalse);
      expect(pet.ageYears, isNull);
      expect(pet.ageLabel, isNull);
    });

    test('copyWith keeps every field it is not given', () {
      final until = DateTime(2025, 6, 17);
      final pet = Pet(
        id: 'p',
        name: 'Pip',
        species: PetSpecies.bird,
        weightKg: 0.035,
        sex: PetSex.unknown,
        neutered: Neutered.no,
        photoPath: 'demo/p/avatar_1.jpg',
        iconKey: 'budgie:sage',
        reminderSnoozedUntil: until,
      );
      final copy = pet.copyWith(weightKg: 0.04);
      expect(copy.weightKg, 0.04);
      expect(copy.species, PetSpecies.bird);
      expect(copy.sex, PetSex.unknown);
      expect(copy.neutered, Neutered.no);
      expect(copy.photoPath, 'demo/p/avatar_1.jpg');
      expect(copy.iconKey, 'budgie:sage');
      expect(copy.reminderSnoozedUntil, until);
    });

    test('a birthday replaces an age that was given directly', () {
      const pet = Pet(id: 'kelly', name: 'Kelly', ageYears: 13.6);
      final copy = pet.copyWith(birthDate: DateTime(2020, 6, 10));
      expect(copy.ageLabelAt(today), '5 years');
    });

    test('withBasics stores the answers exactly, clearing what was unanswered', () {
      const pet = Pet(id: 'p', name: 'Pip', breed: 'Poodle', weightKg: 7, sex: PetSex.male, ageYears: 4);
      final cleared = pet.withBasics(
        name: 'Pippa',
        species: PetSpecies.cat,
        breed: null,
        weightKg: null,
        sex: null,
        neutered: Neutered.unknown,
      );
      expect(cleared.name, 'Pippa');
      expect(cleared.species, PetSpecies.cat);
      expect(cleared.breed, isNull);
      expect(cleared.weightKg, isNull);
      expect(cleared.sex, isNull);
      expect(cleared.neutered, Neutered.unknown);
      expect(cleared.hasAge, isFalse);

      final kept = pet.withBasics(
        name: 'Pip',
        species: PetSpecies.dog,
        breed: 'Poodle',
        weightKg: 7,
        sex: PetSex.male,
        neutered: null,
        keepAge: true,
      );
      expect(kept.ageYears, 4);
    });

    test('a picture is a photo, an icon, or the default of its kind', () {
      const pet = Pet(id: 'kelly', name: 'Kelly', photoAsset: 'assets/images/kelly.png');
      expect(pet.hasPhoto, isTrue);

      final withIcon = pet.withPicture(iconKey: 'dog_pointy:peach');
      expect(withIcon.hasPhoto, isFalse);
      expect(withIcon.photoAsset, isNull);
      expect(withIcon.iconKey, 'dog_pointy:peach');

      final withPhoto = withIcon.withPicture(photoPath: 'demo/kelly/avatar_1.jpg');
      expect(withPhoto.hasPhoto, isTrue);
      expect(withPhoto.iconKey, isNull);
    });

    test('archiving and postponing the reminder can be undone', () {
      const pet = Pet(id: 'p', name: 'Pip');
      final archived = pet.withArchivedAt(today);
      expect(archived.isArchived, isTrue);
      expect(archived.withArchivedAt(null).isArchived, isFalse);

      final snoozed = pet.withReminderSnoozedUntil(today);
      expect(snoozed.reminderSnoozedUntil, today);
      expect(snoozed.withReminderSnoozedUntil(null).reminderSnoozedUntil, isNull);
    });
  });

  group('pets rows', () {
    test('a pet survives the trip to a database row and back', () {
      final pet = Pet(
        id: '6f1c2f0e-0000-4000-8000-000000000001',
        name: ' Kiwi ',
        species: PetSpecies.bird,
        breed: 'Budgerigar',
        weightKg: 0.035,
        birthDate: DateTime(2024, 3, 9),
        birthDateApprox: true,
        sex: PetSex.female,
        neutered: Neutered.unknown,
        iconKey: 'budgie:sage',
        feeding: const FeedingStatus(dailyGoal: 40),
      );
      final row = petToRow('owner-1', pet);
      expect(row['owner_id'], 'owner-1');
      expect(row['name'], 'Kiwi');
      expect(row['species'], 'bird');
      expect(row['birth_date'], '2024-03-09');
      expect(row['birth_date_approx'], isTrue);
      expect(row['weight_kg'], 0.035);
      expect(row['sex'], 'female');
      expect(row['neutered'], 'unknown');
      expect(row['archived_at'], isNull);

      final back = petFromRow({...row, 'created_at': '2025-06-10T10:00:00Z'});
      expect(back.name, 'Kiwi');
      expect(back.species, PetSpecies.bird);
      expect(back.weightKg, 0.035);
      expect(back.birthDate, DateTime(2024, 3, 9));
      expect(back.birthDateApprox, isTrue);
      expect(back.sex, PetSex.female);
      expect(back.neutered, Neutered.unknown);
      expect(back.iconKey, 'budgie:sage');
      expect(back.feeding.dailyGoal, 40);
      expect(back.isArchived, isFalse);
    });

    test('unanswered fields are stored as nulls, and read back as not answered', () {
      final row = petToRow('owner-1', const Pet(id: 'id', name: 'Soya', breed: '  '));
      expect(row['breed'], isNull);
      expect(row['birth_date'], isNull);
      expect(row['birth_date_approx'], isFalse);
      expect(row['sex'], isNull);
      expect(row['neutered'], isNull);
      expect(row['photo_path'], isNull);

      final back = petFromRow(row);
      expect(back.sex, isNull);
      expect(back.neutered, isNull);
      expect(back.hasAge, isFalse);
      expect(back.species, PetSpecies.dog);
    });

    test('an archived, postponed pet keeps both moments', () {
      final archived = DateTime.utc(2025, 6, 1, 8);
      final snoozed = DateTime.utc(2025, 6, 17, 8);
      final row = petToRow(
        'owner-1',
        const Pet(id: 'id', name: 'Milo').withArchivedAt(archived).withReminderSnoozedUntil(snoozed),
      );
      final back = petFromRow(row);
      expect(back.archivedAt!.toUtc(), archived);
      expect(back.reminderSnoozedUntil!.toUtc(), snoozed);
    });

    test('a species this version does not know reads as "other"', () {
      expect(petFromRow({'id': 'x', 'name': 'Rex', 'species': 'dragon'}).species, PetSpecies.other);
    });
  });

  group('the Supabase backend', () {
    test('weights are sent to the gram, so a 35 g bird is not rounded away', () {
      expect(petToRow('o', const Pet(id: 'id', name: 'Kiwi', weightKg: 0.0351234))['weight_kg'], 0.035);
      expect(petToRow('o', const Pet(id: 'id', name: 'Rex', weightKg: 23.4567))['weight_kg'], 23.457);
    });

    test('failures are reported in plain words, never as raw errors', () {
      String message(Object error, {String doing = 'save your pet'}) =>
          petsExceptionFor(error, doing: doing).message;

      expect(
        message(const sb.PostgrestException(message: 'new row violates row-level security policy', code: '42501')),
        'You can only change your own pets. Please sign in again.',
      );
      expect(
        message(const sb.PostgrestException(message: 'violates check constraint "pets_sex_check"', code: '23514')),
        'Some of that information is not valid. Please check it and try again.',
      );
      expect(
        message(const sb.PostgrestException(message: 'column pets.icon_key does not exist', code: '42703')),
        'The database is not up to date for pets yet (migration 0005 has not been run).',
      );
      expect(
        message(const sb.PostgrestException(message: "Could not find the 'sex' column", code: 'PGRST204')),
        'The database is not up to date for pets yet (migration 0005 has not been run).',
      );
      expect(message(const sb.PostgrestException(message: 'JWT expired', code: 'PGRST301')), 'Please sign in again.');
      expect(
        message(const sb.PostgrestException(message: 'boom', code: 'XX000'), doing: 'load your pets'),
        'Could not load your pets. Please try again.',
      );
      expect(
        message(const sb.StorageException('The object exceeded the maximum allowed size', statusCode: '413')),
        'That photo is too large.',
      );
      expect(
        message(const sb.StorageException('mime type image/gif is not supported')),
        'That kind of picture is not supported.',
      );
      expect(message(const sb.StorageException('Object not found')), 'That photo is no longer available.');
      expect(
        message(const sb.StorageException('nope', statusCode: '500'), doing: 'save the photo'),
        'Could not save the photo. Please try again.',
      );
      expect(message(const sb.AuthException('session missing')), 'Please sign in again.');
      expect(
        message(TimeoutException('slow')),
        'Cannot reach the server. Check your connection and try again.',
      );
      expect(
        message(Exception('SocketException: Failed host lookup')),
        'Cannot reach the server. Check your connection and try again.',
      );
      expect(message(StateError('odd')), 'Something went wrong. Please try again.');
      expect(message(const PetsException('Already in words.')), 'Already in words.');
    });

    test('migration 0005 only adds: nothing is dropped, and row level security is stated', () {
      final sql = File('supabase/migrations/0005_pets.sql').readAsStringSync().toLowerCase();
      for (final column in ['sex', 'neutered', 'birth_date_approx', 'icon_key', 'archived_at', 'reminder_snoozed_until']) {
        expect(sql, contains('add column if not exists $column '), reason: column);
      }
      expect(sql, contains('alter column weight_kg type numeric(7, 3)'));
      expect(sql, contains('enable row level security'));
      expect(sql, contains('create policy "pets: owner has full access"'));
      expect(sql, contains('with check (auth.uid() = owner_id)'));
      expect(sql, isNot(contains('drop table')));
      expect(sql, isNot(contains('drop column')));
      expect(sql, isNot(contains('delete from')));
      expect(sql, isNot(contains('truncate')));
      // Every statement that would fail on a second run is guarded.
      expect(RegExp(r'add constraint (\w+)').allMatches(sql).length,
          RegExp(r'drop constraint if exists (\w+)').allMatches(sql).length);
      expect(sql, contains('drop policy if exists "pets: owner has full access"'));
    });

    test('every column the app writes exists after 0001 and 0005', () {
      final schema = '${File('supabase/migrations/0001_profiles_and_pets.sql').readAsStringSync()}\n'
          '${File('supabase/migrations/0005_pets.sql').readAsStringSync()}';
      final row = petToRow('owner', const Pet(id: 'id', name: 'Soya'));
      for (final column in row.keys) {
        expect(RegExp('\\b$column\\b').hasMatch(schema), isTrue, reason: 'column $column');
      }
    });
  });

  group('FakePetsRepository', () {
    test('the demo account owns Kelly and Soya; any other account starts empty', () async {
      final repo = FakePetsRepository(latency: Duration.zero);
      expect([for (final p in await repo.fetchPets('demo')) p.id], ['kelly', 'soya']);
      expect(await repo.fetchPets('u2'), isEmpty);
      expect(repo.cachedPets('u2'), isEmpty);
      // Nobody signed in: screens pumped on their own still see the samples.
      expect([for (final p in repo.cachedPets(null)!) p.id], ['kelly', 'soya']);
    });

    test('saves, updates and deletes a pet', () async {
      final repo = FakePetsRepository(latency: Duration.zero);
      await repo.savePet('u2', const Pet(id: 'a', name: 'Pip'));
      await repo.savePet('u2', const Pet(id: 'a', name: 'Pippa'));
      expect([for (final p in await repo.fetchPets('u2')) p.name], ['Pippa']);

      await repo.deletePet('u2', const Pet(id: 'a', name: 'Pippa'));
      expect(await repo.fetchPets('u2'), isEmpty);
    });

    test('a pet needs a name', () async {
      final repo = FakePetsRepository(latency: Duration.zero);
      expect(() => repo.savePet('u2', const Pet(id: 'a', name: ' ')), throwsA(isA<PetsException>()));
    });

    test('photos live in the owner and pet folder and go with the pet', () async {
      final repo = FakePetsRepository(latency: Duration.zero);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final path = await repo.uploadPhoto('u2', 'a', bytes);
      expect(path, startsWith('u2/a/'));
      expect((await repo.loadPhoto(path)).bytes, bytes);

      await repo.deletePet('u2', const Pet(id: 'a', name: 'Pip'));
      expect(repo.photos, isEmpty);
      expect(() => repo.loadPhoto(path), throwsA(isA<PetsException>()));
    });

    test('a failure is reported in words', () async {
      final repo = FakePetsRepository(latency: Duration.zero)..failure = 'Cannot reach the server.';
      expect(
        () => repo.fetchPets('demo'),
        throwsA(isA<PetsException>().having((e) => e.message, 'message', 'Cannot reach the server.')),
      );
    });
  });

  group('pets providers', () {
    test('with nobody signed in the sample pets are there, as before', () {
      final container = PetsHarness().container();
      expect([for (final p in container.read(petsProvider)) p.id], ['kelly', 'soya']);
      expect(container.read(selectedPetProvider).id, 'kelly');
      expect(container.read(petsGateProvider), PetsGate.ready);
    });

    test('the demo account keeps Kelly and Soya', () async {
      final container = PetsHarness().container();
      await _signInDemo(container);
      expect([for (final p in container.read(petsProvider)) p.name], ['Kelly', 'Soya']);
      expect(container.read(selectedPetProvider).name, 'Kelly');
      expect(container.read(petsGateProvider), PetsGate.ready);
    });

    test('a new account has no pets: the gate is "empty" and the selected pet is "none"', () async {
      final container = PetsHarness().container();
      await _signUp(container);
      expect(container.read(petsProvider), isEmpty);
      expect(container.read(petsGateProvider), PetsGate.empty);
      expect(container.read(selectedPetProvider).id, Pet.none.id);
    });

    test('saving the first pet opens the gate, and the pet is stored for the owner', () async {
      final harness = PetsHarness();
      final container = harness.container();
      await _signUp(container);
      final ownerId = container.read(authControllerProvider).value!.id;

      final stored = await container.read(petsStoreProvider.notifier).save(const Pet(id: 'new-1', name: 'Pip'));
      expect(stored.name, 'Pip');
      expect(container.read(petsGateProvider), PetsGate.ready);
      expect(container.read(selectedPetProvider).id, 'new-1');
      expect([for (final p in await harness.pets.fetchPets(ownerId)) p.id], ['new-1']);
      // Nothing leaks into another account.
      expect([for (final p in await harness.pets.fetchPets('demo')) p.id], ['kelly', 'soya']);
    });

    test('a save that fails changes nothing and says why', () async {
      final harness = PetsHarness();
      final container = harness.container();
      await _signUp(container);
      harness.pets.failure = 'Could not save your pet. Please try again.';

      await expectLater(
        container.read(petsStoreProvider.notifier).save(const Pet(id: 'new-1', name: 'Pip')),
        throwsA(isA<PetsException>()),
      );
      expect(container.read(petsProvider), isEmpty);
      expect(container.read(petsGateProvider), PetsGate.empty);
    });

    test('pets that have to be fetched show "loading", then arrive', () async {
      final harness = PetsHarness(pets: FakePetsRepository(latency: Duration.zero, instant: false));
      final container = harness.container();
      await _signInDemo(container);
      expect(container.read(petsGateProvider), PetsGate.loading);
      expect(container.read(petsProvider), isEmpty);

      await _settle();
      expect(container.read(petsGateProvider), PetsGate.ready);
      expect([for (final p in container.read(petsProvider)) p.id], ['kelly', 'soya']);
      expect(container.read(selectedPetProvider).id, 'kelly');
    });

    test('a failed load is reported, and "try again" recovers', () async {
      final harness = PetsHarness(pets: FakePetsRepository(latency: Duration.zero, instant: false));
      harness.pets.failure = 'Cannot reach the server.';
      final container = harness.container();
      await _signInDemo(container);
      container.read(petsGateProvider);
      await _settle();
      expect(container.read(petsGateProvider), PetsGate.failed);
      expect(container.read(petsStoreProvider).error, 'Cannot reach the server.');

      harness.pets.failure = null;
      container.read(petsStoreProvider.notifier).retry();
      container.read(petsGateProvider);
      await _settle();
      expect(container.read(petsGateProvider), PetsGate.ready);
    });

    test('update and add keep their signatures and now also save', () async {
      final harness = PetsHarness();
      final container = harness.container();
      await _signInDemo(container);
      final kellyPet = container.read(petsProvider).first;

      container.read(petsProvider.notifier).update(kellyPet.copyWith(weightKg: 22.6));
      expect(container.read(petsProvider).first.weightKg, 22.6);
      container.read(petsProvider.notifier).add(const Pet(id: 'milo', name: 'Milo', species: PetSpecies.cat));
      expect([for (final p in container.read(petsProvider)) p.id], ['kelly', 'soya', 'milo']);

      await _settle();
      final stored = await harness.pets.fetchPets('demo');
      expect(stored.first.weightKg, 22.6);
      expect(stored.last.name, 'Milo');
    });

    test('an update that cannot be saved is taken back', () async {
      final harness = PetsHarness();
      final container = harness.container();
      await _signInDemo(container);
      final kellyPet = container.read(petsProvider).first;

      harness.pets.failure = 'Cannot reach the server.';
      container.read(petsProvider.notifier).update(kellyPet.copyWith(weightKg: 22.6));
      expect(container.read(petsProvider).first.weightKg, 22.6);
      container.read(petsProvider.notifier).add(const Pet(id: 'milo', name: 'Milo'));

      await _settle();
      // The app shows what the backend has.
      expect(container.read(petsProvider).first.weightKg, 23);
      expect([for (final p in container.read(petsProvider)) p.id], ['kelly', 'soya']);
    });

    test('a photo that failed to load is tried again; a loaded one is kept', () async {
      final harness = PetsHarness();
      final container = harness.container();
      final path = await harness.pets.uploadPhoto('demo', 'kelly', testPhoto);

      harness.pets.failure = 'Cannot reach the server.';
      final failed = container.listen(petPhotoProvider(path), (_, _) {});
      await _settle();
      expect(failed.read().hasError, isTrue);
      failed.close();
      await _settle();

      harness.pets.failure = null;
      final loaded = container.listen(petPhotoProvider(path), (_, _) {});
      await _settle();
      expect(loaded.read().value!.bytes, testPhoto);
      loaded.close();
      await _settle();

      // Kept for the session: no second trip to the backend.
      harness.pets.failure = 'Cannot reach the server.';
      expect(container.read(petPhotoProvider(path)).value!.bytes, testPhoto);
    });

    test('updating a pet the owner does not have stores nothing', () async {
      final harness = PetsHarness();
      final container = harness.container();
      await _signInDemo(container);
      container.read(petsProvider.notifier).update(const Pet(id: 'stranger', name: 'Rex'));
      await _settle();
      expect([for (final p in await harness.pets.fetchPets('demo')) p.id], ['kelly', 'soya']);
    });

    test('an archived pet leaves the list the tabs see, and can be restored', () async {
      final harness = PetsHarness();
      final container = harness.container();
      await _signInDemo(container);
      final store = container.read(petsStoreProvider.notifier);
      final soyaPet = container.read(petsProvider).last;

      await store.save(soyaPet.withArchivedAt(petsNow));
      expect([for (final p in container.read(petsProvider)) p.id], ['kelly']);
      expect([for (final p in container.read(archivedPetsProvider)) p.id], ['soya']);

      await store.save(container.read(archivedPetsProvider).single.withArchivedAt(null));
      expect([for (final p in container.read(petsProvider)) p.id], ['kelly', 'soya']);
      expect(container.read(archivedPetsProvider), isEmpty);
    });

    test('when the selected pet is archived the first remaining one is shown', () async {
      final container = PetsHarness().container();
      await _signInDemo(container);
      container.read(selectedPetIdProvider.notifier).select('soya');
      expect(container.read(selectedPetProvider).id, 'soya');

      final soyaPet = container.read(selectedPetProvider);
      await container.read(petsStoreProvider.notifier).save(soyaPet.withArchivedAt(petsNow));
      expect(container.read(selectedPetProvider).id, 'kelly');
    });

    test('deleting the last pet closes the gate again', () async {
      final harness = PetsHarness();
      final container = harness.container();
      await _signUp(container);
      final store = container.read(petsStoreProvider.notifier);
      final pet = await store.save(const Pet(id: 'new-1', name: 'Pip'));
      expect(container.read(petsGateProvider), PetsGate.ready);

      await store.delete(pet);
      expect(container.read(petsProvider), isEmpty);
      expect(container.read(petsGateProvider), PetsGate.empty);
    });

    test('signing out and in as someone else switches the pets', () async {
      final container = PetsHarness().container();
      await _signInDemo(container);
      container.read(selectedPetIdProvider.notifier).select('soya');
      await container.read(authControllerProvider.notifier).signOut();
      await _signUp(container);
      expect(container.read(petsProvider), isEmpty);
      expect(container.read(selectedPetProvider).id, Pet.none.id);

      await container.read(authControllerProvider.notifier).signOut();
      await _signInDemo(container);
      expect(container.read(selectedPetProvider).id, 'kelly');
    });
  });

  group('first-pet gate', () {
    testWidgets('the demo account lands on Home', (tester) async {
      await pumpPetsApp(tester);
      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Kelly'), findsNWidgets(2));
    });

    testWidgets('a new account sees the welcome instead of the tabs', (tester) async {
      await pumpPetsApp(tester, as: SignedIn.newAccount);
      expect(find.text('Welcome, Limor'), findsOneWidget);
      expect(find.text('Add my first pet'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Feeding'), findsNothing);
    });

    testWidgets('"Sign out" on the welcome returns to the login screen', (tester) async {
      await pumpPetsApp(tester, as: SignedIn.newAccount);
      await tapVisible(tester, find.text('Sign out'));
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('a failed load says so; "Try again" carries on to Home', (tester) async {
      final harness = PetsHarness(pets: FakePetsRepository(latency: Duration.zero, instant: false));
      harness.pets.failure = 'Cannot reach the server. Check your connection and try again.';
      await pumpPetsApp(tester, harness: harness);

      expect(find.text('Could not load your pets'), findsOneWidget);
      expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);
      expect(find.text('Add my first pet'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);

      harness.pets.failure = null;
      await tapVisible(tester, find.text('Try again'));
      expect(find.text('Feeding'), findsOneWidget);
    });

    testWidgets('pets that take a moment to load keep the splash, then Home', (tester) async {
      final harness = PetsHarness(
        pets: FakePetsRepository(latency: const Duration(seconds: 5), instant: false),
      );
      await pumpPetsApp(tester, harness: harness);
      expect(find.text('Feeding'), findsNothing);
      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('Add my first pet'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Feeding'), findsOneWidget);
    });
  });
}
