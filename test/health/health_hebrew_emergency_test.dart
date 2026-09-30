import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/health/health_strings.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';
import 'health_test_helpers.dart';

// Health's emergency pieces in Hebrew and right to left: the button, the
// sheet, the message to a vet, the Emergency card, the vets, the health
// basics and the emergency kit. These are also what Home, the add-a-pet
// flow and the pet profile place. An overflow anywhere fails the test by
// itself, and the test font makes Hebrew letters as wide as Latin ones, so
// the layouts are checked as strictly as the English ones.

final he = lookupHealthL10n(hebrewLocale);
final en = lookupHealthL10n(englishLocale);
final appHe = lookupAppL10n(hebrewLocale);
final appEn = lookupAppL10n(englishLocale);

const kelly = 'kelly';
const soya = 'soya';
const parkPhone = '+972 3 555 0142';

/// A strip with the button, as a header would place it.
Widget button(String petId) => Row(children: [EmergencyButton(petId: petId, onCoral: false)]);

Future<HealthHarness> openSheet(
  WidgetTester tester,
  String petId, {
  HealthHarness? harness,
  Size size = widePhone,
}) async {
  final h = await pumpHealthHost(tester, button(petId), harness: harness ?? hebrewHealth(), size: size);
  await tester.tap(find.byType(EmergencyButton));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final size in [widePhone, smallPhone]) {
    final width = size.width.toInt();

    testWidgets('the emergency button, the sheet and the message to a vet in Hebrew ($width px)', (tester) async {
      final h = await pumpHealthHost(tester, button(kelly), harness: hebrewHealth(), size: size);

      // The button.
      expect(find.text('חירום'), findsOneWidget);
      expect(find.text('Emergency'), findsNothing);
      expect(find.bySemanticsLabel(he.emergencyContactsFor('Kelly')), findsOneWidget);
      expect(directionOf(tester, find.text('חירום')), TextDirection.rtl);

      // The sheet.
      await tester.tap(find.byType(EmergencyButton));
      await tester.pumpAndSettle();
      expect(find.text(he.emergencySheetTitle('Kelly')), findsOneWidget);
      expect(find.text(he.emergencySheetSubtitle), findsOneWidget);
      expect(find.text('וטרינר קבוע'), findsOneWidget);
      expect(find.text('וטרינר חירום (24 שעות)'), findsOneWidget);
      expect(find.text('איש קשר לחירום'), findsOneWidget);
      expect(find.text('חיוג'), findsNWidgets(3));
      expect(find.text('הודעה'), findsNWidgets(3));
      expect(find.text('מפה'), findsNWidgets(2));
      expect(find.text(he.openEmergencyCardOf('Kelly')), findsOneWidget);
      expect(find.text(he.emergencyKit), findsOneWidget);
      expect(find.text(he.petIsLost('Kelly')), findsOneWidget);
      expect(find.text(he.safetyLine), findsOneWidget);
      for (final english in ['Call', 'Message', 'Map', 'Regular vet', 'Emergency contact', 'Emergency kit']) {
        expect(find.text(english), findsNothing, reason: english);
      }
      // What the owner typed stays as typed; a phone number stays in one
      // piece, left to right.
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
      expect(find.text(ltr(parkPhone)), findsOneWidget);
      expect(find.text(parkPhone), findsNothing);

      // Call still dials the plain number.
      await tapVisible(tester, find.byKey(const ValueKey('call-regular')));
      expect(h.launcher.calls.single.target, parkPhone);

      // The message.
      await tapVisible(tester, find.byKey(const ValueKey('message-regular')));
      expect(find.text(he.messageTo('Dr. Levi, Park Vet Clinic')), findsOneWidget);
      expect(find.text(he.whatIsHappening), findsOneWidget);
      expect(find.text(he.messagePreviewLabel), findsOneWidget);
      expect(find.text(he.greetingNamed('Alex', 'Kelly')), findsOneWidget);
      expect(find.textContaining('כלב'), findsOneWidget); // Kelly: dog, Mix, 13.6 years, 23 kg
      expect(find.textContaining('23\u2069 ק״ג'), findsOneWidget);
      expect(find.textContaining('אלרגיות: '), findsOneWidget);
      expect(find.textContaining('מחלות רקע: '), findsOneWidget);
      expect(find.textContaining('תרופות: '), findsOneWidget);
      expect(find.text(he.messageMicrochip(ltr('985 112 004 567 321'))), findsOneWidget);
      expect(find.text(he.messageFinePrint), findsOneWidget);
      expect(find.text(he.openInWhatsApp), findsOneWidget);

      await tester.enterText(find.byKey(const Key('message-what')), 'מקיאה מהבוקר');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('remove-line-microchip')));
      expect(find.text(he.putRemovedLinesBack), findsOneWidget);
      await tapVisible(tester, find.text(he.openInMessages));

      final sent = h.launcher.calls.last;
      expect(sent.action, ContactAction.textMessage);
      expect(sent.target, parkPhone);
      expect(sent.body, startsWith('${he.greetingNamed('Alex', 'Kelly')}\nמקיאה מהבוקר'));
      expect(sent.body, contains('אלרגיות: '));
      expect(sent.body, contains('Chicken (skin reaction)'));
      expect(sent.body, isNot(contains('שבב')));
      expect(sent.body, isNot(contains('Allergies')));
    });

    testWidgets('the Emergency card, the vets and the vet form in Hebrew ($width px)', (tester) async {
      await openSheet(tester, kelly, size: size);

      await tapVisible(tester, find.text(he.openEmergencyCardOf('Kelly')));
      expect(find.text('כרטיס חירום'), findsOneWidget);
      expect(directionOf(tester, find.text('כרטיס חירום')), TextDirection.rtl);
      // The back arrow leads: it is on the right in Hebrew.
      expect(tester.getCenter(find.byTooltip(appHe.commonBack)).dx, greaterThan(size.width / 2));
      expect(find.byTooltip(he.shareSummary), findsOneWidget);
      expect(find.text('שבב'), findsOneWidget);
      expect(find.text(ltr('985 112 004 567 321')), findsOneWidget);
      expect(find.text('אלרגיות'), findsOneWidget);
      expect(find.text('מחלות רקע'), findsOneWidget);
      expect(find.text(he.activeMedicines), findsOneWidget);
      // Kind, breed, age and weight in the Pets feature's Hebrew words.
      expect(find.textContaining('כלב · '), findsOneWidget);
      expect(find.textContaining('שנים'), findsOneWidget);
      expect(find.text(he.shareSummary), findsOneWidget);
      expect(find.text(he.editHealthProfile), findsOneWidget);
      expect(find.text(he.emergencyCardFinePrint), findsOneWidget);
      expect(find.text('Emergency card'), findsNothing);
      expect(find.text('Allergies'), findsNothing);

      // The vets.
      await tapVisible(tester, find.text(he.petsVets('Kelly')));
      expect(find.text(he.petsVets('Kelly')), findsOneWidget);
      expect(find.text('וטרינר קבוע'), findsOneWidget);
      expect(find.text('וטרינר חירום (24 שעות)'), findsOneWidget);
      expect(find.text(he.change), findsNWidgets(2));
      expect(find.text('כתובת'), findsNWidgets(2));
      expect(find.text('טלפון'), findsNWidgets(2));
      expect(find.text('שעות פתיחה'), findsNWidgets(2));
      expect(find.text('WhatsApp'), findsOneWidget); // the app's name stays in Latin letters
      expect(find.text(he.vetsFinePrint), findsOneWidget);
      expect(find.byTooltip(he.editNamed('City Animal Hospital')), findsOneWidget);

      // The vet form and its checks.
      await tapVisible(tester, find.byKey(const ValueKey('edit-vet-regular')));
      expect(find.text('עריכת וטרינר'), findsOneWidget);
      expect(find.byTooltip(he.deleteVet), findsOneWidget);
      expect(find.text(he.whoIsIt), findsOneWidget);
      expect(find.text(he.howToReachThem), findsOneWidget);
      expect(find.text(he.onWhatsApp), findsOneWidget);
      expect(find.text(he.onWhatsAppNote(ltr('+972'))), findsOneWidget);
      expect(find.text(he.vetFormFinePrint), findsOneWidget);
      // A phone number is typed left to right.
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: find.byKey(const Key('vet-phone')), matching: find.byType(EditableText)),
            )
            .textDirection,
        TextDirection.ltr,
      );

      await tester.enterText(find.byKey(const Key('vet-name')), '');
      await tester.enterText(find.byKey(const Key('vet-phone')), '03 555 0777');
      await tapVisible(tester, find.text(he.saveVet));
      expect(find.text(he.validVetName), findsOneWidget);
      expect(find.text(he.validWhatsAppCountryCode(ltr('+972'))), findsOneWidget);

      await tester.enterText(find.byKey(const Key('vet-phone')), 'abc');
      await tapVisible(tester, find.text(he.saveVet));
      expect(find.text(he.validPhone), findsOneWidget);

      // Deleting asks first, in Hebrew.
      await tester.tap(find.byTooltip(he.deleteVet));
      await tester.pumpAndSettle();
      expect(find.text(he.deleteVetTitle), findsOneWidget);
      expect(find.text(he.deleteVetMessage('Dr. Levi, Park Vet Clinic')), findsOneWidget);
      expect(find.text(appHe.commonDelete), findsOneWidget);
      await tester.tap(find.text(appHe.commonCancel));
      await tester.pumpAndSettle();
      expect(find.text(he.deleteVetTitle), findsNothing);
    });

    testWidgets('a pet without a vet: the prompt, the picker and a new vet in Hebrew ($width px)', (tester) async {
      final h = await openSheet(tester, soya, size: size);

      expect(find.text(he.noVetSavedFor('Soya')), findsOneWidget);
      expect(find.text(he.noVetSavedNote), findsOneWidget);
      expect(find.text(he.useSavedVet), findsOneWidget);
      expect(find.text(he.useVet), findsNWidgets(2));
      expect(find.text('הוספת וטרינר חדש'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('add-new-vet')));
      expect(find.text('הוספת וטרינר'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('vet-name')), 'המרפאה ברחוב הירוק');
      await tester.enterText(find.byKey(const Key('vet-phone')), '+972 3 555 0777');
      await tapVisible(tester, find.text(he.saveVet));

      expect(find.text('המרפאה ברחוב הירוק'), findsOneWidget);
      expect(find.text(ltr('+972 3 555 0777')), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('call-regular')));
      expect(h.launcher.calls.single.target, '+972 3 555 0777');
    });

    testWidgets('the vet tile and the health basics, as the add-a-pet flow places them, in Hebrew ($width px)', (
      tester,
    ) async {
      HealthProfile? saved;
      await pumpHealthHost(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PetVetTile(petId: soya),
              const SizedBox(height: 8),
              const PetVetTile(petId: soya, role: VetRole.emergency),
              HealthBasicsSection(petId: soya, onSaved: (profile) => saved = profile),
            ],
          ),
        ),
        harness: hebrewHealth(),
        size: size,
      );

      expect(find.text('הוספת וטרינר'), findsOneWidget);
      expect(find.text(he.vetPromptNote), findsOneWidget);
      expect(find.text(he.addEmergencyVet), findsOneWidget);
      expect(find.text(he.emergencyVetPromptNote), findsOneWidget);
      expect(find.text(he.identification), findsOneWidget);
      expect(find.text(he.microchipNumberOptional), findsOneWidget);
      expect(find.text('אלרגיות'), findsOneWidget);
      expect(find.text(he.knownAllergies), findsOneWidget);
      expect(find.text('מחלות רקע'), findsOneWidget);
      expect(find.text('לא ידוע על כאלה'), findsNWidgets(2));
      expect(find.text('אין שבב'), findsOneWidget);
      // The button says "Save" in Hebrew unless the page names it.
      expect(find.text('שמירה'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('None known'), findsNothing);

      // The picker.
      await tapVisible(tester, find.text(he.addEmergencyVet));
      expect(find.text(he.chooseEmergencyVet), findsOneWidget);
      expect(find.text(he.vetPickerNote), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-city')));
      expect(find.text('וטרינר חירום (24 שעות)'), findsOneWidget);
      expect(find.text('City Animal Hospital'), findsOneWidget);
      expect(find.text(he.change), findsOneWidget);

      // The basics: a number that is too long is refused in Hebrew.
      await tester.enterText(find.byKey(const Key('profile-microchip')), '9' * 41);
      await tapVisible(tester, find.text('שמירה'));
      expect(find.text(he.validNumberTooLong(40)), findsOneWidget);
      expect(saved, isNull);

      await tester.enterText(find.byKey(const Key('profile-microchip')), '');
      await tapVisible(tester, find.byKey(const Key('profile-not-chipped')));
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await tester.enterText(find.byKey(const Key('profile-conditions')), 'אוושה בלב');
      await tapVisible(tester, find.text('שמירה'));
      expect(saved, isNotNull);
      expect(saved!.notChipped, isTrue);
      expect(saved!.allergiesNoneKnown, isTrue);
      expect(saved!.conditions, ['אוושה בלב']);
    });

    testWidgets("Health's own profile page in Hebrew ($width px)", (tester) async {
      await pumpHealthHost(tester, const SizedBox(height: 10), harness: hebrewHealth(), size: size);
      unawaited(openHealthProfile(tester.element(find.byType(SizedBox).first), kelly));
      await tester.pumpAndSettle();

      expect(find.text(he.petsHealthProfile('Kelly')), findsOneWidget);
      expect(find.text(he.emergencyContactHeading), findsOneWidget);
      expect(find.text(he.nameOptional), findsOneWidget);
      expect(find.text(he.phoneOptional), findsOneWidget);
      expect(find.text(he.anythingElseForVet), findsOneWidget);
      expect(find.text(he.notesOptional), findsOneWidget);
      expect(find.text(he.profileFinePrint), findsOneWidget);

      await tester.enterText(find.byKey(const Key('profile-contact-phone')), 'abc');
      await tapVisible(tester, find.text(he.saveProfile));
      expect(find.text(he.validPhone), findsOneWidget);
    });

    testWidgets('the emergency kit in Hebrew ($width px)', (tester) async {
      await openSheet(tester, kelly, size: size);
      expect(find.text(he.kitSomeReady(3, 6)), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('open-emergency-kit')));
      expect(find.text(he.petsEmergencyKit('Kelly')), findsOneWidget);
      expect(find.text('3 מתוך 6 מוכנים'), findsOneWidget);
      expect(find.text(he.kitSummaryNote), findsOneWidget);
      for (final title in [
        he.kitCarrierDog,
        he.kitFoodWater,
        he.kitDocuments,
        he.kitMicrochip,
        he.kitMedicines,
        he.kitShelterPlan,
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text(he.kitDocumentsNoteDog), findsOneWidget);
      expect(find.text(he.kitMicrochipNumber(ltr('985 112 004 567 321'))), findsOneWidget);
      expect(find.text(he.kitShelterPlanNote('Kelly')), findsOneWidget);
      expect(find.text(he.kitTicked('02.06.25')), findsNWidgets(2));
      expect(find.text(he.kitOurPlan), findsOneWidget);
      expect(find.text(he.kitFinePrint), findsOneWidget);
      expect(find.text(he.kitDocumentsSaved(4)), findsOneWidget);
      expect(find.text('Documents'), findsNothing);

      // Ticking the rest says "All 6 ready" in Hebrew.
      for (final item in ['foodWater', 'medicines', 'shelterPlan']) {
        await tapVisible(tester, find.byKey(ValueKey('kit-$item')));
      }
      expect(find.text('כל 6 הפריטים מוכנים'), findsOneWidget);
    });
  }

  testWidgets('what the phone cannot open is explained in Hebrew, with the number left to right', (tester) async {
    final h = await openSheet(tester, kelly);
    h.launcher.succeeds = false;

    await tapVisible(tester, find.byKey(const ValueKey('call-regular')));
    expect(find.text(he.couldNotOpenPhone), findsOneWidget);
    expect(find.text(he.copyNumber), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).textDirection, TextDirection.ltr);
    await tester.tap(find.text(appHe.commonClose));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('map-regular')));
    expect(find.text(he.couldNotOpenMaps), findsOneWidget);
    expect(find.text(he.copyAddress), findsOneWidget);
    await tester.tap(find.text(appHe.commonClose));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('message-regular')));
    await tapVisible(tester, find.text(he.openInWhatsApp));
    expect(find.text(he.couldNotOpenWhatsApp), findsOneWidget);
    expect(find.text(he.copyMessage), findsOneWidget);
  });

  testWidgets('contacts that cannot be loaded say why in Hebrew, and recover', (tester) async {
    final h = hebrewHealth();
    h.repository.failing = true;
    await openSheet(tester, kelly, harness: h);

    expect(find.text(he.loadFailedContacts), findsOneWidget);
    expect(find.text(he.errOffline), findsOneWidget);
    expect(find.textContaining('Could not'), findsNothing);

    h.repository.failing = false;
    await tester.tap(find.text('לנסות שוב'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
  });

  testWidgetsInBothLanguages('a contact with only a phone number is called "Emergency contact"', (
    tester,
    language,
  ) async {
    final h = HealthHarness(language: language);
    await real(tester, () => h.repository.saveProfile(const HealthProfile(petId: soya, contactPhone: '050 111 2222')));
    await openSheet(tester, soya, harness: h);
    // Once as who it is, once in place of the name nobody typed.
    expect(find.text(h.l10n.emergencyContact), findsNWidgets(2));
    expect(find.text(h.isHebrew ? 'איש קשר לחירום' : 'Emergency contact'), findsNWidgets(2));
  });

  group('failure reasons', () {
    test('every reason has its own words in both languages', () {
      for (final failure in HealthFailure.values) {
        final error = HealthException.of(failure);
        final english = healthErrorText(en, appEn, error);
        final hebrew = healthErrorText(he, appHe, error);
        expect(english, failure.english, reason: failure.name);
        expect(hasHebrew(hebrew), isTrue, reason: failure.name);
        expect(hebrew, isNot(contains('Could')), reason: failure.name);
        if (failure != HealthFailure.unknown) {
          expect(hebrew, isNot(appHe.errorGeneric), reason: failure.name);
        }
      }
      // No two reasons share their Hebrew.
      final all = {for (final failure in HealthFailure.values) healthErrorText(he, appHe, HealthException.of(failure))};
      expect(all, hasLength(HealthFailure.values.length));
    });

    test('words from elsewhere show on an English screen and become a plain line in Hebrew', () {
      const custom = HealthException('Printer on fire.');
      expect(healthErrorText(en, appEn, custom), 'Printer on fire.');
      expect(healthErrorText(he, appHe, custom), appHe.errorGeneric);
      expect(healthErrorText(en, appEn, StateError('x')), appEn.errorGeneric);
      expect(healthErrorText(he, appHe, StateError('x')), 'משהו השתבש. אפשר לנסות שוב.');
      // The English-only helper, for logs.
      expect(healthErrorMessage(HealthException.of(HealthFailure.vetGone)), 'That vet no longer exists.');
    });

    test('a file that cannot be attached gives its reason', () {
      expect(testPhoto().failure, isNull);
      expect(hugePdf().failure, HealthFailure.fileTooLarge);
      expect(
        PickedFile(name: 'a.gif', mimeType: 'image/gif', bytes: testPhoto().bytes).failure,
        HealthFailure.fileType,
      );
      expect(he.failure(HealthFailure.fileTooLarge, appHe), 'הקובץ הזה גדול מ־5 מ״ב. אפשר לבחור קובץ קטן יותר.');
    });
  });

  group('plural forms', () {
    test('documents saved in the kit: one, two, many', () {
      expect(he.kitDocumentsSaved(1), 'מסמך אחד שמור כאן');
      expect(he.kitDocumentsSaved(2), 'שני מסמכים שמורים כאן');
      expect(he.kitDocumentsSaved(7), '7 מסמכים שמורים כאן');
      expect(en.kitDocumentsSaved(1), '1 document saved here');
      expect(en.kitDocumentsSaved(2), '2 documents saved here');
    });
  });

  test('a Hebrew sentence keeps a Latin name in one piece', () {
    // Every text placeholder sits between U+2068 and U+2069.
    expect(he.emergencySheetTitle('Kelly'), 'חירום · \u2068Kelly\u2069');
    expect(he.addPetsVet('Kelly'), 'הוספת וטרינר עבור \u2068Kelly\u2069');
    expect(he.greetingNamed('Alex', 'Kelly'), 'שלום, כאן \u2068Alex\u2069, הבעלים של \u2068Kelly\u2069.');
    expect(en.emergencySheetTitle('Kelly'), 'Emergency · Kelly');
  });
}
