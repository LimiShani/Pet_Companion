import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/health_rows.dart' show lostCardFromRow, lostCardToRow;
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/health/emergency/lost_card_view.dart';
import 'package:pet_companion/features/health/share/lost_card_renderer.dart';
import 'package:pet_companion/features/pets/pets.dart' show PetPhotoData, PetsException;
import 'package:pet_companion/models/pet.dart';

import 'health_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const kelly = 'kelly';
  const soya = 'soya';
  const phone = '050-555-0117';
  final preview = find.byKey(const Key('lost-card-preview'));

  Future<HealthHarness> openSheet(WidgetTester tester, String petId, {HealthHarness? harness}) async {
    final h = await pumpHealthHost(
      tester,
      Row(children: [EmergencyButton(petId: petId, onCoral: false)]),
      harness: harness,
    );
    await tester.tap(find.byType(EmergencyButton));
    await tester.pumpAndSettle();
    return h;
  }

  /// The "is lost" page, opened from the emergency sheet.
  Future<HealthHarness> openLost(WidgetTester tester, String petId, {HealthHarness? harness}) async {
    final h = await openSheet(tester, petId, harness: harness);
    await tapVisible(tester, find.byKey(const Key('open-lost-card')));
    return h;
  }

  Finder onCard(String text) => find.descendant(of: preview, matching: find.text(text));
  bool enabled(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label)).onPressed != null;
  bool? confirmBox(WidgetTester tester) =>
      tester.widget<CheckboxListTile>(find.byKey(const Key('lost-confirm-phone'))).value;

  Future<void> fill(WidgetTester tester, {String area = 'Florentin, Tel Aviv'}) async {
    await tester.enterText(find.byKey(const Key('lost-description')), 'Light brown, medium, red collar. Shy.');
    await tester.enterText(find.byKey(const Key('lost-area')), area);
    await tester.enterText(find.byKey(const Key('lost-phone')), phone);
    await tester.pumpAndSettle();
  }

  group('"My pet is lost"', () {
    testWidgets('opens from the emergency sheet and shows the card as it will look', (tester) async {
      await openSheet(tester, kelly);
      expect(find.text('Kelly is lost'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('open-lost-card')));
      expect(find.text('What goes on the card'), findsOneWidget);
      expect(find.text('This is what will be shared'), findsOneWidget);

      // Hebrew by default: the card is read by neighbours.
      // The name sits in one piece between invisible direction marks.
      expect(onCard('מחפשים את \u2068Kelly\u2069'), findsOneWidget);
      expect(onCard('הוכן באפליקציית PetLoop'), findsOneWidget);
      expect(Directionality.of(tester.element(onCard('מחפשים את \u2068Kelly\u2069'))), TextDirection.rtl);

      // Nothing can be shared before a phone number is given and confirmed.
      expect(find.text('Add your phone number, then confirm it here.'), findsOneWidget);
      expect(enabled(tester, 'Share as image'), isFalse);
      expect(find.textContaining('Nothing is posted by the app'), findsOneWidget);
    });

    testWidgets('the phone number appears on the card only after it is confirmed', (tester) async {
      final h = await openLost(tester, kelly);
      await fill(tester);

      expect(onCard('Light brown, medium, red collar. Shy.'), findsOneWidget);
      expect(onCard('Florentin, Tel Aviv'), findsOneWidget);
      expect(onCard('\u206810.06.25\u2069, בסביבות \u206817:40\u2069'), findsOneWidget);
      expect(find.text('Show this phone number on the card: $phone'), findsOneWidget);
      expect(onCard(phone), findsNothing);
      expect(enabled(tester, 'Share as image'), isFalse);

      await tapVisible(tester, find.byKey(const Key('lost-confirm-phone')));
      expect(confirmBox(tester), isTrue);
      expect(onCard(phone), findsOneWidget);
      expect(onCard('ראיתם את \u2068Kelly\u2069? התקשרו'), findsOneWidget);
      expect(enabled(tester, 'Share as image'), isTrue);

      // Another number needs another confirmation.
      await tester.enterText(find.byKey(const Key('lost-phone')), '052-000-1234');
      await tester.pumpAndSettle();
      expect(confirmBox(tester), isFalse);
      expect(onCard('052-000-1234'), findsNothing);
      expect(enabled(tester, 'Share as image'), isFalse);
      expect(h.sharer.shared, isEmpty);
    });

    testWidgets('shares a picture through the share sheet and keeps the draft', (tester) async {
      final h = await openLost(tester, kelly);
      await fill(tester);
      await tapVisible(tester, find.byKey(const Key('lost-confirm-phone')));
      await tapVisible(tester, find.text('Share as image'));

      expect(h.cardRenderer.pictures, 1);
      final file = h.sharer.shared.single;
      expect(file.name, 'kelly-lost-card.png');
      expect(file.mimeType, 'image/png');
      expect(file.subject, 'מחפשים את Kelly');
      // Nothing was opened or sent anywhere else.
      expect(h.launcher.calls, isEmpty);

      final draft = (await real(tester, () => h.repository.fetchLostCard(kelly)))!;
      expect(draft.description, 'Light brown, medium, red collar. Shy.');
      expect(draft.area, 'Florentin, Tel Aviv');
      expect(draft.phone, phone);
      expect(draft.language, LostCardLanguage.hebrew);
      expect(draft.lastSeenAt, fixedNow);
      expect(draft.foundAt, isNull);
    });

    testWidgets('can be shared as a PDF to print, and in English', (tester) async {
      final h = await openLost(tester, kelly);
      await fill(tester);
      await tapVisible(tester, find.byKey(const ValueKey('lost-language-en')));

      expect(onCard('Looking for Kelly'), findsOneWidget);
      expect(onCard('Area'), findsOneWidget);
      expect(onCard('10.06.25, around 17:40'), findsOneWidget);
      expect(onCard('Made with PetLoop'), findsOneWidget);
      expect(Directionality.of(tester.element(onCard('Looking for Kelly'))), TextDirection.ltr);

      await tapVisible(tester, find.byKey(const Key('lost-confirm-phone')));
      expect(onCard('Seen Kelly? Please call'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('lost-share-pdf')));

      expect(h.cardRenderer.pdfTitles, ['Looking for Kelly']);
      final file = h.sharer.shared.single;
      expect(file.name, 'kelly-lost-card.pdf');
      expect(file.mimeType, 'application/pdf');
      expect((await real(tester, () => h.repository.fetchLostCard(kelly)))!.language, LostCardLanguage.english);
    });

    testWidgets('never carries the chip number, the vet or a saved address', (tester) async {
      await openLost(tester, kelly);
      await fill(tester);

      // Kelly has a chip: the card says so, without the number.
      expect(onCard('יש שבב'), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.textContaining('985')), findsNothing);
      expect(find.descendant(of: preview, matching: find.textContaining('Park')), findsNothing);
      // The area field starts empty: no address is ever filled in.
      await tester.enterText(find.byKey(const Key('lost-area')), '');
      await tester.pumpAndSettle();
      expect(onCard('אזור'), findsNothing);
      expect(find.text('A neighbourhood or a street corner is enough. Not your home address.'), findsOneWidget);

      // A house number gets a gentle hint.
      await tester.enterText(find.byKey(const Key('lost-area')), 'Herzl 12, Tel Aviv');
      await tester.pumpAndSettle();
      expect(
        find.text('This looks like an exact address. A neighbourhood or a street corner is safer.'),
        findsOneWidget,
      );
    });

    testWidgets('a pet without a chip or a photo gets a card without them', (tester) async {
      final h = await openLost(tester, soya);

      expect(onCard('מחפשים את \u2068Soya\u2069'), findsOneWidget);
      expect(onCard('יש שבב'), findsNothing);
      expect(find.text('No photo on the card'), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.byType(Image)), findsNothing);
      expect(h.cardPhotos.asked, [soya]);
    });

    testWidgets("uses the pet's photo, or one chosen just for the card", (tester) async {
      final h = HealthHarness();
      h.cardPhotos.photo = MemoryImage(FakeHealthRepository.samplePng);
      h.picker.photo = testPhoto('today.png');
      await openLost(tester, kelly, harness: h);

      expect(find.text("Kelly's photo"), findsOneWidget);
      expect(find.text('From the pet profile'), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.byType(Image)), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('lost-change-photo')));
      expect(h.picker.asked, ['gallery']);
      expect(find.text('Chosen for this card only'), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.byType(Image)), findsOneWidget);
    });

    testWidgets('an unusable phone number cannot be confirmed', (tester) async {
      await openLost(tester, kelly);
      await tester.enterText(find.byKey(const Key('lost-phone')), 'call me');
      await tester.pumpAndSettle();

      expect(find.text('That does not look like a phone number.'), findsOneWidget);
      expect(find.text('Add your phone number, then confirm it here.'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('lost-confirm-phone'))).onChanged, isNull);
    });

    testWidgets('says so when the card or the share sheet is not available', (tester) async {
      final h = await openLost(tester, kelly);
      await fill(tester);
      await tapVisible(tester, find.byKey(const Key('lost-confirm-phone')));

      h.cardRenderer.failing = true;
      await tapVisible(tester, find.text('Share as image'));
      expect(find.text('Could not prepare the card. Please try again.'), findsOneWidget);
      expect(h.sharer.shared, isEmpty);

      h.cardRenderer.failing = false;
      h.sharer.succeeds = false;
      await tapVisible(tester, find.text('Share as image'));
      expect(find.text('Could not open the share sheet on this device.'), findsOneWidget);

      // A draft that cannot be saved never stands in the way of sharing.
      h.sharer.succeeds = true;
      h.repository.failing = true;
      await tapVisible(tester, find.text('Share as image'));
      expect(h.sharer.shared, hasLength(2));
      expect(find.text('Could not open the share sheet on this device.'), findsNothing);
    });

    testWidgets('nothing is retyped next time, and "back home" puts the card away', (tester) async {
      final h = await openLost(tester, kelly);
      await fill(tester);
      await tester.enterText(find.byKey(const Key('lost-extra')), 'Needs a daily medicine');
      await tapVisible(tester, find.byKey(const Key('lost-confirm-phone')));
      await tapVisible(tester, find.text('Share as image'));
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Opened again, this time from the Emergency card.
      await tapVisible(tester, find.text("Open Kelly's Emergency card"));
      await tapVisible(tester, find.byKey(const Key('open-lost-card')));
      expect(find.widgetWithText(TextFormField, 'Florentin, Tel Aviv'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, phone), findsOneWidget);
      expect(onCard('Needs a daily medicine'), findsOneWidget);
      // The confirmation is asked again every time.
      expect(confirmBox(tester), isFalse);
      expect(onCard(phone), findsNothing);

      await tapVisible(tester, find.byKey(const Key('lost-back-home')));
      expect(find.text('Emergency card'), findsOneWidget);
      expect(find.text('Good news. The card is put away.'), findsOneWidget);
      expect((await real(tester, () => h.repository.fetchLostCard(kelly)))!.foundAt, fixedNow);

      // A later search starts from what stays true.
      await tapVisible(tester, find.byKey(const Key('open-lost-card')));
      expect(find.widgetWithText(TextFormField, 'Light brown, medium, red collar. Shy.'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, phone), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Florentin, Tel Aviv'), findsNothing);
      expect(find.byKey(const Key('lost-back-home')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens for another tab through openLostPetCard', (tester) async {
      await pumpHealthHost(tester, const SizedBox(height: 10));
      openLostPetCard(tester.element(find.byType(SizedBox).first), soya).ignore();
      await tester.pumpAndSettle();
      expect(find.text('Soya is lost'), findsOneWidget);
    });
  });

  group('card content', () {
    final at = DateTime(2025, 6, 10, 16, 30);

    test('Hebrew and English cards say the same things', () {
      LostCardContent card(LostCardLanguage language) => LostCardContent(
        language: language,
        petName: 'קלי',
        description: 'כלבה מעורבת, קולר אדום',
        area: 'פלורנטין, תל אביב',
        lastSeenAt: at,
        microchipped: true,
        phone: phone,
        extra: '',
      );
      final he = card(LostCardLanguage.hebrew);
      expect(he.heading, 'מחפשים את \u2068קלי\u2069');
      expect(he.facts, [
        ('אזור', 'פלורנטין, תל אביב'),
        ('מתי', '\u206810.06.25\u2069, בסביבות \u206816:30\u2069'),
        ('שבב', 'יש שבב'),
      ]);
      expect(he.words.rightToLeft, isTrue);
      expect(he.allText, containsAll(['ראיתם את \u2068קלי\u2069? התקשרו', phone]));

      final en = card(LostCardLanguage.english);
      expect(en.heading, 'Looking for קלי');
      expect(en.facts.map((f) => f.$1), ['Area', 'When', 'Microchip']);
      expect(en.facts.last.$2, 'Microchipped');
      expect(en.words.rightToLeft, isFalse);
      expect(en.allText, contains('Seen קלי? Please call'));
    });

    test('what was not given is left out', () {
      const card = LostCardContent(language: LostCardLanguage.english, petName: 'Soya');
      expect(card.facts, isEmpty);
      expect(card.allText, ['Looking for Soya', 'Made with PetLoop']);
    });

    test('a house number reads as an exact address; file names stay plain', () {
      expect(looksLikeExactAddress('Herzl 12, Tel Aviv'), isTrue);
      expect(looksLikeExactAddress('Florentin, Tel Aviv'), isFalse);
      expect(lostCardFileName('Kelly', 'png'), 'kelly-lost-card.png');
      expect(lostCardFileName('קלי', 'pdf'), 'pet-lost-card.pdf');
    });

    test('a draft keeps every field on its way to the database and back', () {
      final draft = LostPetCard(
        petId: 'p',
        description: 'Light brown',
        area: 'Florentin',
        lastSeenAt: at,
        phone: phone,
        extra: 'Needs a daily medicine',
        language: LostCardLanguage.english,
        foundAt: DateTime(2025, 6, 11, 9),
      );
      final row = lostCardToRow(draft);
      expect(row['language'], 'en');
      final back = lostCardFromRow(row);
      expect(back.description, 'Light brown');
      expect(back.area, 'Florentin');
      expect(back.lastSeenAt, at);
      expect(back.phone, phone);
      expect(back.extra, 'Needs a daily medicine');
      expect(back.language, LostCardLanguage.english);
      expect(back.foundAt, DateTime(2025, 6, 11, 9));
      // An unknown language falls back to the default.
      expect(lostCardFromRow({...row, 'language': 'xx'}).language, LostCardLanguage.hebrew);
    });
  });

  group('photo and picture', () {
    test('the photo comes from the pet profile, or there is none', () async {
      final bytes = FakeHealthRepository.samplePng;
      Future<ImageProvider?> photo(Pet pet, Future<PetPhotoData> Function(String) load) =>
          PetProfilePhotoSource(load).photoOf(pet);
      Future<PetPhotoData> never(String path) => throw StateError('not asked');

      const stored = Pet(id: 'a', name: 'A', photoPath: 'u/a/avatar_1.jpg');
      expect(await photo(stored, (_) async => PetPhotoData.bytes(bytes)), isA<MemoryImage>());
      final linked = await photo(stored, (_) async => PetPhotoData.url(Uri.parse('https://example.com/a.jpg')));
      expect(linked, isA<CachedNetworkImageProvider>());
      // A photo that cannot be loaded leaves the card without a picture.
      expect(await photo(stored, (_) async => throw const PetsException('gone')), isNull);

      const sample = Pet(id: 'kelly', name: 'Kelly', photoAsset: 'assets/images/kelly.png');
      expect(await photo(sample, never), isA<AssetImage>());
      // An icon is not a photo.
      expect(await photo(const Pet(id: 'b', name: 'B', iconKey: 'cat_1'), never), isNull);
    });

    testWidgets('the card on screen becomes a PNG, and a one-page PDF', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: key,
                child: LostCardView(
                  content: LostCardContent(
                    language: LostCardLanguage.hebrew,
                    petName: 'קלי',
                    description: 'כלבה מעורבת, קולר אדום',
                    area: 'פלורנטין',
                    lastSeenAt: DateTime(2025, 6, 10, 16, 30),
                    phone: phone,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const renderer = WidgetLostCardRenderer();
      final png = (await tester.runAsync(() => renderer.png(key, width: 240)))!;
      expect(png.sublist(0, 8), Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      final pdf = (await tester.runAsync(() => renderer.pdf(png, title: 'מחפשים את קלי')))!;
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');

      // Nothing on screen under the key: a friendly failure, not a crash.
      final problem = await tester.runAsync<Object?>(() async {
        try {
          await renderer.png(GlobalKey());
          return null;
        } catch (error) {
          return error;
        }
      });
      expect(
        problem,
        isA<HealthException>().having((e) => e.message, 'message', contains('Could not prepare the card')),
      );
    });
  });
}
