import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/data/photo_services.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/pets/picture/crop_photo_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';

import 'pets_test_helpers.dart';

// The Pets feature in Hebrew and right to left. An overflow anywhere fails
// the test by itself, and the test font makes Hebrew letters as wide as
// Latin ones, so these layouts are checked as strictly as the English ones.
// Health's own pieces inside the flow (the vet tiles, the health basics
// section) are Health's to translate; they are found here by key or type.

final appHe = lookupAppL10n(hebrewLocale);
final appEn = lookupAppL10n(englishLocale);

const wide = Size(390, 844);
const small = Size(320, 568);

PetsHarness hebrew({FakePetsRepository? pets}) => PetsHarness(pets: pets, language: AppLanguage.hebrew);

TextDirection directionOf(WidgetTester tester, Finder finder) => Directionality.of(tester.element(finder));

/// Buttons that open the pets pages from a page of their own.
Widget openers(String petId) => Builder(
      builder: (context) => Column(
        children: [
          TextButton(onPressed: () => showPetChecklist(context, petId), child: const Text('checklist')),
          TextButton(onPressed: () => openPetProfile(context, petId), child: const Text('profile')),
          TextButton(onPressed: () => openMyPets(context), child: const Text('my pets')),
        ],
      ),
    );

/// The pet is saved, "No connection" comes back for everything else.
class _Offline extends FakePetsRepository {
  _Offline() : super(latency: Duration.zero);

  @override
  Future<Pet> savePet(String ownerId, Pet pet) async => throw PetsException.of(PetsFailure.offline);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final size in [wide, small]) {
    final width = size.width.toInt();

    testWidgets('the welcome and the whole add-a-pet flow in Hebrew ($width px)', (tester) async {
      await pumpPetsApp(tester, harness: hebrew(), as: SignedIn.newAccount, size: size);

      // The welcome.
      expect(find.text(he.welcomeTitleNamed('Limor')), findsOneWidget);
      expect(find.text('הוספת החיה הראשונה שלי'), findsOneWidget);
      expect(find.text(he.welcomeWhyVet), findsOneWidget);
      expect(find.text(appHe.accountSignOut), findsOneWidget);
      expect(find.text('Pet Companion'), findsOneWidget); // the name stays in Latin letters
      expect(find.text('Add my first pet'), findsNothing);
      expect(directionOf(tester, find.text(he.welcomeAddFirst)), TextDirection.rtl);

      // Step 1.
      await tapVisible(tester, find.text(he.welcomeAddFirst));
      expect(find.text('הוספת חיה'), findsOneWidget);
      expect(find.text('את מי מצרפים למשפחה?'), findsOneWidget);
      expect(find.text(he.stepOf(1, 4)), findsOneWidget);
      for (final kind in ['כלב', 'חתול', 'ציפור', 'ארנב', 'זוחל', 'אחר']) {
        expect(find.text(kind), findsOneWidget);
      }
      expect(find.text(he.savedOnContinueNoName), findsOneWidget);
      // The back arrow leads: it is on the right in Hebrew.
      expect(tester.getCenter(find.byTooltip(appHe.commonBack)).dx, greaterThan(size.width / 2));

      await tapVisible(tester, find.text(appHe.commonContinue));
      expect(find.text(he.nameMissingNew), findsOneWidget);

      // The picture sheet and the icon bank.
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      expect(find.text(he.yourPetsPicture), findsOneWidget);
      expect(find.text(he.takeAPhoto), findsOneWidget);
      expect(find.text(he.chooseFromPhotos), findsOneWidget);
      expect(find.text(he.pickAnIconNote(13)), findsOneWidget);
      await tapVisible(tester, find.text(he.pickAnIcon));
      expect(find.text(he.iconsForDog), findsOneWidget);
      expect(find.text(he.iconsAll), findsOneWidget);
      expect(find.text(he.iconsBackground), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('icon-dog_pointy')));
      await tapVisible(tester, find.byKey(const Key('icon-bg-sage')));
      await tapVisible(tester, find.text(he.iconsUse));

      await typeInto(tester, find.byKey(const Key('pet-name')), 'Milo');
      expect(find.text(he.savedOnContinue('Milo')), findsOneWidget);
      await tapVisible(tester, find.text(appHe.commonContinue));

      // Step 2.
      expect(find.text(he.aboutPetTitle('Milo')), findsOneWidget);
      expect(find.text(he.petIsSaved('Milo')), findsOneWidget);
      expect(find.text(he.finishLater), findsOneWidget);
      expect(find.text('תאריך לידה או גיל'), findsOneWidget);
      expect(find.text(he.tagEssential), findsNWidgets(2));
      expect(find.text(he.iKnowTheDate), findsOneWidget);
      expect(find.text(he.unitYears), findsOneWidget);
      expect(find.text(he.unitMonths), findsOneWidget);
      expect(find.text(he.neuteredOrSpayed), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, he.notSure), findsNWidgets(2));
      expect(find.text(he.mixedOrNotSure), findsWidgets);
      expect(currentPets(tester).single.iconKey, 'dog_pointy:sage');

      await typeInto(tester, find.byKey(const Key('pet-weight')), '1.2.3');
      await tapVisible(tester, find.text(appHe.commonContinue));
      expect(find.text(he.enterANumberLike(18)), findsOneWidget);

      await typeInto(tester, find.byKey(const Key('pet-age-amount')), '3');
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, he.sexFemale));
      await tapVisible(tester, find.text(appHe.commonContinue));

      // Step 3.
      expect(find.text(he.petVetTitle('Milo')), findsOneWidget);
      expect(find.text(he.whoLooksAfter('Milo')), findsOneWidget);
      expect(find.text('וטרינר קבוע'), findsOneWidget);
      expect(find.text('וטרינר חירום (24 שעות)'), findsOneWidget);
      expect(find.text(he.tagOptional), findsOneWidget);
      expect(find.text(he.noVetYetNote('Milo')), findsOneWidget);
      await tapVisible(tester, find.text(he.noVetYet));

      // Step 4.
      expect(find.text(he.healthBasics), findsOneWidget);
      expect(find.text(he.whatAVetAsksFirst), findsOneWidget);
      expect(find.text(he.stepOf(4, 4)), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await tapVisible(tester, find.text(he.finish));

      // All set.
      expect(find.text('הפרופיל של ${isolate('Milo')} מוכן'), findsOneWidget);
      expect(find.text(he.allSetSomeFilled(3, 5)), findsOneWidget);
      expect(find.text(he.ageAbout(he.ageYears(3))), findsOneWidget);
      expect(find.text(he.weightKg('18')), findsOneWidget);
      expect(find.text(he.noneKnown), findsOneWidget);
      expect(find.text(he.itemVetPhone), findsOneWidget);
      expect(find.text(he.addNow), findsNWidgets(2));
      expect(find.text(he.addAnotherPet), findsOneWidget);
      expect(find.text(he.allSetNoteRest('Milo')), findsOneWidget);

      final pet = petNamed(tester, 'Milo');
      expect(pet.sex, PetSex.female);
      expect(pet.weightKg, 18);
      expect(pet.birthDateApprox, isTrue);

      // The dashboard is Home's page: checked at the usual width only.
      if (size == wide) {
        await tapVisible(tester, find.text(he.goToDashboard('Milo')));
        expect(find.text('האכלה'), findsOneWidget);
        expect(find.text('Milo'), findsNWidgets(2));
      }
    });

    testWidgets('the reminder, the checklist, the profile and My pets in Hebrew ($width px)', (tester) async {
      await pumpPetsHost(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const PetReminderCard(petId: soya, compact: true, margin: EdgeInsets.only(bottom: 12)),
              const PetReminderCard(petId: soya),
              openers(soya),
            ],
          ),
        ),
        harness: hebrew(),
        size: size,
      );

      // The reminder in both sizes.
      expect(find.text(he.finishProfile('Soya')), findsOneWidget);
      expect(find.text('חסרים 5 מתוך 5 פרטים חיוניים'), findsNWidgets(2));
      expect(find.text(he.actionVetPhone), findsNWidgets(2));
      expect(find.text('לא עכשיו'), findsNWidgets(2));
      expect(find.bySemanticsLabel(he.reminderSemantics('Soya', 5, 5)), findsNWidgets(2));
      expect(directionOf(tester, find.text(he.finishProfile('Soya'))), TextDirection.rtl);
      // "Not now" ends the line: on the left in Hebrew.
      expect(tester.getCenter(find.text(he.notNow).first).dx, lessThan(size.width / 2));

      // The checklist, and an answer given from it.
      await tapVisible(tester, find.text('checklist'));
      expect(find.text(he.checklistTitle('Soya')), findsOneWidget);
      expect(find.text(he.checklistSomeAnswered(0, 5)), findsOneWidget);
      for (final item in PetInfoItem.essentials) {
        expect(find.text(item.labelIn(he)), findsOneWidget);
      }
      expect(find.text(he.hintVetPhone), findsOneWidget);
      expect(find.text(he.goodToHave), findsOneWidget);
      expect(find.byTooltip(he.chipNotAdded(he.itemBreed)), findsOneWidget);
      expect(find.widgetWithText(FilledButton, appHe.commonAdd), findsNWidgets(5));

      await tapVisible(tester, find.byKey(const Key('add-weight')));
      expect(find.text(he.petWeightTitle('Soya')), findsOneWidget);
      expect(find.text(he.petWeightNote), findsOneWidget);
      expect(find.text(he.unitKg), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.text(appHe.commonSave));
      expect(find.text(he.checklistSomeAnswered(1, 5)), findsOneWidget);
      expect(find.text('${isolate('18')} ק״ג'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('add-age')));
      expect(find.text(he.petAgeTitle('Soya')), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-age-amount')), '2');
      await tapVisible(tester, find.text(appHe.commonSave));
      expect(find.text(he.ageAbout('שנתיים')), findsOneWidget);

      await tapVisible(tester, find.text(he.remindInAWeek));
      expect(find.text(he.checklistTitle('Soya')), findsNothing);
      expect(find.text(he.remindAgainInAWeek), findsOneWidget);
      expect(find.text(he.finishProfile('Soya')), findsNothing);
      await tapVisible(tester, find.text('checklist'));
      expect(find.text(he.reminderHiddenUntil('17.06.25', 'Soya')), findsOneWidget);
      Navigator.of(tester.element(find.text(he.checklistTitle('Soya')))).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5)); // let the message go
      await tester.pumpAndSettle();

      // The profile.
      await tapVisible(tester, find.text('profile'));
      final pet = petNamed(tester, 'Soya');
      expect(find.text(petSummaryLine(he, pet, now: petsNow)), findsOneWidget);
      expect(find.text('כלב · בערך ${isolate('שנתיים')}'), findsOneWidget);
      expect(find.text(he.changePicture), findsOneWidget);
      expect(find.text(he.myPetsTitle), findsOneWidget);
      expect(find.text(he.essentialsStillToAdd(3, 5)), findsOneWidget);
      for (final label in [he.basics, he.birthdayOrAge, he.sex, he.neuteredOrSpayed, he.vet, he.healthBasics]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text(he.notAnsweredYet), findsNWidgets(2));
      expect(find.text(he.notAdded), findsOneWidget);
      expect(find.text(he.answer), findsNWidgets(2));
      expect(find.text(he.saveChanges), findsOneWidget);
      expect(tester.getCenter(find.byTooltip(appHe.commonBack)).dx, greaterThan(size.width / 2));

      await tapVisible(tester, find.byKey(const Key('pet-kind')));
      expect(find.text('חתול'), findsWidgets);
      await tester.tap(find.text('חתול').last);
      await tester.pumpAndSettle();
      await typeInto(tester, find.byKey(const Key('pet-name')), '  ');
      await tapVisible(tester, find.text(he.saveChanges));
      expect(find.text(he.nameMissing), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Soya');
      await tapVisible(tester, find.text(he.saveChanges));
      expect(find.text('השינויים נשמרו'), findsOneWidget);
      expect(petNamed(tester, 'Soya').species, PetSpecies.cat);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Archive or delete.
      await tapVisible(tester, find.text(he.deletePet('Soya')));
      expect(find.text(he.removePetTitle('Soya')), findsOneWidget);
      expect(find.text(he.suggested), findsOneWidget);
      expect(find.text(he.archiveNote('Soya')), findsOneWidget);
      expect(find.text('מחיקה לצמיתות'), findsOneWidget);
      expect(find.text(he.deleteNote('Soya')), findsOneWidget);
      expect(find.text(appHe.commonCancel), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('remove-archive')));
      expect(find.text(he.petArchived('Soya')), findsOneWidget);
      expect(find.text(he.changePicture), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // My pets, with the archived one.
      await tapVisible(tester, find.text('my pets'));
      expect(find.text('החיות שלי'), findsOneWidget);
      expect(find.text(he.complete), findsOneWidget);
      expect(find.text(he.addPetTitle), findsOneWidget);
      expect(find.text(he.archived), findsOneWidget);
      expect(find.text(he.archivedRow('חתול', '10.06.25')), findsOneWidget);
      expect(find.text(he.archivedNote), findsOneWidget);
      // A row starts with the picture: on the right in Hebrew.
      expect(tester.getCenter(find.byType(PetAvatar).first).dx, greaterThan(size.width / 2));

      await tapVisible(tester, find.byKey(const Key('restore-soya')));
      expect(find.text(he.petIsBack('Soya')), findsOneWidget);
      expect(find.text(he.essentialsToAdd(3)), findsOneWidget);
      expect(find.text(he.archived), findsNothing);
    });
  }

  group('messages in Hebrew', () {
    testWidgets('a known birthday is picked from a Hebrew calendar', (tester) async {
      await pumpPetsApp(tester, harness: hebrew(), as: SignedIn.newAccount);
      await tapVisible(tester, find.text(he.welcomeAddFirst));
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Milo');
      await tapVisible(tester, find.text(appHe.commonContinue));

      await tapVisible(tester, find.text(he.iKnowTheDate));
      expect(find.text(he.chooseTheDate), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('pet-age-date')));
      final picker = tester.element(find.byType(DatePickerDialog));
      expect(Directionality.of(picker), TextDirection.rtl);
      await tester.tap(find.text(MaterialLocalizations.of(picker).okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text('10.06.2025'), findsOneWidget);

      await tapVisible(tester, find.text(appHe.commonContinue));
      expect(petNamed(tester, 'Milo').birthDate, DateTime(2025, 6, 10));
    });

    testWidgets('a failure the app knows is said in Hebrew', (tester) async {
      await pumpPetsApp(tester, harness: hebrew(pets: _Offline()), as: SignedIn.newAccount);
      await tapVisible(tester, find.text(he.welcomeAddFirst));
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Milo');
      await tapVisible(tester, find.text(appHe.commonContinue));

      expect(find.text('אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.'), findsOneWidget);
      expect(find.text(he.whoIsJoining), findsOneWidget);
    });

    testWidgets('words the app does not know are replaced by a plain Hebrew line', (tester) async {
      final harness = hebrew();
      await pumpPetsApp(tester, harness: harness, as: SignedIn.newAccount);
      harness.pets.failure = 'The backend said something in English.';
      await tapVisible(tester, find.text(he.welcomeAddFirst));
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Milo');
      await tapVisible(tester, find.text(appHe.commonContinue));

      expect(find.text(appHe.errorGeneric), findsOneWidget);
      expect(find.text('The backend said something in English.'), findsNothing);
    });

    testWidgets('a failed load of the pets says so in Hebrew and recovers', (tester) async {
      final harness = hebrew(pets: FakePetsRepository(latency: Duration.zero, instant: false));
      harness.pets.failure = 'boom';
      await pumpPetsApp(tester, harness: harness);

      expect(find.text('לא הצלחנו לטעון את החיות שלך'), findsOneWidget);
      expect(find.text(appHe.errorGeneric), findsOneWidget);
      expect(find.text(appHe.accountSignOut), findsOneWidget);

      harness.pets.failure = null;
      await tapVisible(tester, find.text(appHe.commonTryAgain));
      expect(find.text('האכלה'), findsOneWidget);
    });

    testWidgets('a camera failure with words of its own becomes a plain Hebrew line', (tester) async {
      final harness = hebrew();
      await pumpPetsApp(tester, harness: harness, as: SignedIn.newAccount);
      harness.picker.failure = 'unused';
      await tapVisible(tester, find.text(he.welcomeAddFirst));
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text(he.takeAPhoto));
      // The fake picker fails with words of its own: a plain line in Hebrew.
      expect(find.text(appHe.errorGeneric), findsOneWidget);
    });

    test('every reason has its own words in both languages', () {
      for (final failure in PetsFailure.values) {
        final error = PetsException.of(failure);
        final english = petsErrorText(en, appEn, error);
        final hebrewText = petsErrorText(he, appHe, error);
        expect(english, failure.english, reason: failure.name);
        expect(hebrewText, isNot(english), reason: failure.name);
        expect(RegExp('[א-ת]').hasMatch(hebrewText), isTrue, reason: failure.name);
      }
      // Words from elsewhere: as they are in English, a plain line in Hebrew.
      expect(petsErrorText(en, appEn, const PetsException('From a test.')), 'From a test.');
      expect(petsErrorText(he, appHe, const PetsException('From a test.')), appHe.errorGeneric);
      expect(petsErrorText(he, appHe, StateError('odd')), appHe.errorGeneric);
      expect(petsErrorText(en, appEn, null), appEn.errorGeneric);
    });
  });

  group('the crop screen in Hebrew', () {
    testWidgets('explains itself, and the editor keeps screen coordinates', (tester) async {
      CropOutcome? outcome;
      await pumpPetsHost(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => outcome = await const ScreenPetPhotoCropper().crop(context, testPhoto),
            child: const Text('Crop'),
          ),
        ),
        harness: hebrew(),
        size: small,
      );
      await tester.tap(find.text('Crop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CropPhotoScreen), findsOneWidget);
      expect(find.text('הזזה והגדלה'), findsOneWidget);
      expect(find.text(he.cropHint), findsOneWidget);
      expect(find.text(he.cropPreview), findsOneWidget);
      expect(find.text(he.cropUsePhoto), findsOneWidget);
      expect(directionOf(tester, find.text(he.cropTitle)), TextDirection.rtl);
      // Back leads the title: on the right in Hebrew.
      expect(tester.getCenter(find.byTooltip(appHe.commonBack)).dx, greaterThan(small.width / 2));

      await tester.tap(find.text(he.cropChooseAnother));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(outcome!.another, isTrue);
    });

    testWidgets('a file that is not a picture is refused in Hebrew', (tester) async {
      await pumpPetsHost(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              try {
                await const ScreenPetPhotoCropper().crop(context, Uint8List.fromList([1, 2, 3, 4]));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(petsErrorOf(context, e))));
              }
            },
            child: const Text('Crop'),
          ),
        ),
        harness: hebrew(),
      );
      await tester.tap(find.text('Crop'));
      await tester.pumpAndSettle();
      expect(find.text('סוג התמונה הזה לא נתמך. אפשר לבחור תמונה אחרת.'), findsOneWidget);
    });
  });

  group('the words for a pet', () {
    final today = DateTime(2025, 6, 10);
    Pet born(DateTime date, {bool approx = false}) => Pet(id: 'p', name: 'Pip', birthDate: date, birthDateApprox: approx);

    test('an age is said with the proper plural in each language', () {
      String ageEn(Pet pet) => petAgeText(en, pet, now: today)!;
      String ageHe(Pet pet) => petAgeText(he, pet, now: today)!;

      expect(ageEn(born(DateTime(2024, 6, 1))), '12 months');
      expect(ageEn(born(DateTime(2022, 6, 1))), '3 years');
      expect(ageEn(born(DateTime(2025, 5, 9))), '1 month');
      expect(ageEn(born(DateTime(2025, 5, 27))), '2 weeks');
      expect(ageEn(born(DateTime(2025, 6, 8))), 'Under a week');
      expect(ageEn(born(DateTime(2022, 6, 10), approx: true)), 'About 3 years');
      expect(ageEn(const Pet(id: 'k', name: 'Kelly', ageYears: 13.6)), '13.6 years');
      expect(ageEn(const Pet(id: 'k', name: 'Kelly', ageYears: 1)), '1 year');

      // Hebrew has a form of its own for one and for two.
      expect(ageHe(born(DateTime(2024, 6, 1))), '12 חודשים');
      expect(ageHe(born(DateTime(2023, 6, 1))), 'שנתיים');
      expect(ageHe(born(DateTime(2022, 6, 1))), '3 שנים');
      expect(ageHe(born(DateTime(2025, 5, 9))), 'חודש');
      expect(ageHe(born(DateTime(2025, 4, 9))), 'חודשיים');
      expect(ageHe(born(DateTime(2025, 6, 2))), 'שבוע');
      expect(ageHe(born(DateTime(2025, 5, 27))), 'שבועיים');
      expect(ageHe(born(DateTime(2025, 6, 8))), 'פחות משבוע');
      expect(ageHe(born(DateTime(2022, 6, 10), approx: true)), 'בערך ${isolate('3 שנים')}');
      expect(ageHe(const Pet(id: 'k', name: 'Kelly', ageYears: 13.6)), '${isolate('13.6')} שנים');
      expect(ageHe(const Pet(id: 'k', name: 'Kelly', ageYears: 1)), 'שנה');

      expect(petAgeText(he, const Pet(id: 's', name: 'Soya'), now: today), isNull);
    });

    test('the model gives the age as a number and a unit, without words', () {
      final age = born(DateTime(2022, 6, 10), approx: true).ageAt(today)!;
      expect(age.unit, PetAgeUnit.years);
      expect(age.count, 3);
      expect(age.approx, isTrue);

      final young = born(DateTime(2025, 6, 8)).ageAt(today)!;
      expect(young.unit, PetAgeUnit.weeks);
      expect(young.isUnderAWeek, isTrue);

      final given = const Pet(id: 'k', name: 'Kelly', ageYears: 13.6).ageAt(today)!;
      expect(given.count, isNull);
      expect(given.exactYears, 13.6);
    });

    test('kind, sex and neutering have a word in both languages', () {
      expect([for (final s in PetSpecies.values) petSpeciesText(en, s)], [for (final s in PetSpecies.values) s.label]);
      expect(
        [for (final s in PetSpecies.values) petSpeciesText(he, s)],
        ['כלב', 'חתול', 'ציפור', 'ארנב', 'זוחל', 'אחר'],
      );
      expect([for (final s in PetSex.values) petSexText(en, s)], [for (final s in PetSex.values) s.label]);
      expect([for (final s in PetSex.values) petSexText(he, s)], ['זכר', 'נקבה', 'לא ידוע']);
      expect([for (final n in Neutered.values) petNeuteredText(en, n)], [for (final n in Neutered.values) n.label]);
      expect([for (final n in Neutered.values) petNeuteredText(he, n)], ['כן', 'לא', 'לא ידוע']);
    });

    test('a weight, a breed and the summary line read right in a Hebrew line', () {
      expect(petWeightText(he, 18, PetSpecies.dog), '${isolate('18')} ק״ג');
      expect(petWeightText(he, 0.035, PetSpecies.bird), '${isolate('35')} גרם');

      const mixed = Pet(id: 'p', name: 'Pip', breed: 'Mixed');
      expect(petBreedText(en, mixed), 'Mixed');
      expect(petBreedText(he, mixed), 'מעורב');
      // A breed somebody typed is never translated, only kept in one piece.
      const labrador = Pet(id: 'p', name: 'Pip', breed: 'Labrador', species: PetSpecies.dog);
      expect(petSummaryLine(en, labrador), 'Dog · Labrador');
      expect(petSummaryLine(he, labrador), 'כלב · ${isolate('Labrador')}');
      expect(petSummaryLine(he, const Pet(id: 'p', name: 'Pip', breed: 'לברדור')), 'כלב · לברדור');
      expect(petSummaryLine(en, const Pet(id: 'p', name: 'Pip', breed: 'לברדור')), 'Dog · ${isolate('לברדור')}');

      // A phone number stays left to right inside a Hebrew line.
      expect(phoneInLine(he, '+972 3 555 0142'), ltr('+972 3 555 0142'));
      expect(phoneInLine(en, '+972 3 555 0142'), '+972 3 555 0142');
    });

    test('a name inside a Hebrew sentence cannot reorder it', () {
      expect(he.petIsReady('Soya'), 'הפרופיל של ${isolate('Soya')} מוכן');
      expect(he.archivedRow('כלב', '10.06.25'), contains(isolate('10.06.25')));
      expect(PetInfoItem.weight.actionIn(he, 'Soya'), 'הוספת המשקל של ${isolate('Soya')}');
    });

    test('every essential and every good-to-have item has its words in Hebrew', () {
      for (final item in PetInfoItem.values) {
        for (final text in [item.labelIn(he), item.hintIn(he), item.actionIn(he, 'Soya')]) {
          expect(RegExp('[א-ת]').hasMatch(text), isTrue, reason: '${item.name}: $text');
        }
        expect(item.labelIn(en), isNot(item.labelIn(he)));
      }
    });
  });

  test('nothing of Pets is left untranslated', () {
    final report = jsonDecode(File('lib/features/pets/l10n/gen/untranslated.json').readAsStringSync()) as Map;
    expect(report, isEmpty);

    final english = jsonDecode(File('lib/features/pets/l10n/pets_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final hebrewStrings = jsonDecode(File('lib/features/pets/l10n/pets_he.arb').readAsStringSync()) as Map<String, dynamic>;
    final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
    expect(hebrewStrings.keys.where((key) => !key.startsWith('@')).toSet(), keys);
    expect(keys.length, greaterThan(200));
  });
}
