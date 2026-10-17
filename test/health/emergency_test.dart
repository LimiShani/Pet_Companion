import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/presentation/health_widgets.dart';
import 'package:pet_companion/services/safety/state/safety_providers.dart';
import 'package:pet_companion/theme/app_colors.dart';
import 'package:pet_companion/widgets/app_icon.dart';
import 'package:pet_companion/widgets/area_disc.dart';

import 'health_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const kelly = 'kelly';
  const soya = 'soya';
  const parkPhone = '+972 3 555 0142';

  /// A coral strip with the button, as a header would place it.
  Widget onCoral(String petId, {bool compact = false}) => ColoredBox(
    color: const Color(0xFFEC6A48),
    child: Row(
      children: [EmergencyButton(petId: petId, compact: compact)],
    ),
  );

  Future<HealthHarness> openSheet(WidgetTester tester, String petId, {HealthHarness? harness}) async {
    final h = await pumpHealthHost(tester, onCoral(petId), harness: harness);
    await tester.tap(find.byType(EmergencyButton));
    await tester.pumpAndSettle();
    return h;
  }

  group('EmergencyButton', () {
    testWidgets('is a labelled pill that announces the pet', (tester) async {
      await pumpHealthHost(tester, onCoral(kelly));

      expect(find.text('Emergency'), findsOneWidget);
      expect(find.bySemanticsLabel('Emergency contacts for Kelly'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is AppIcon && w.icon == Icons.emergency_rounded), findsOneWidget);
      // Kelly has a vet to call: no dot.
      expect(find.byKey(const Key('emergency-dot')), findsNothing);
      // A comfortable tap target.
      final size = tester.getSize(find.byType(EmergencyButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('shows a dot while no phone number is saved, and stays enabled', (tester) async {
      await pumpHealthHost(tester, onCoral(soya));

      expect(find.byKey(const Key('emergency-dot')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Emergency contacts for Soya')), findsOneWidget);

      await tester.tap(find.byType(EmergencyButton));
      await tester.pumpAndSettle();
      expect(find.text('No vet saved for Soya yet'), findsOneWidget);
    });

    testWidgets('the compact form is icon-only and never looks like "add"', (tester) async {
      await pumpHealthHost(tester, onCoral(kelly, compact: true));

      expect(find.text('Emergency'), findsNothing);
      expect(find.byWidgetPredicate((w) => w is AppIcon && w.icon == Icons.emergency_rounded), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is AppIcon && w.icon == Icons.add_rounded), findsNothing);
      expect(find.bySemanticsLabel('Emergency contacts for Kelly'), findsOneWidget);
    });

    testWidgets('keeps working when the contacts cannot be loaded', (tester) async {
      final h = HealthHarness();
      h.repository.failing = true;
      await openSheet(tester, kelly, harness: h);

      expect(find.byKey(const Key('emergency-dot')), findsNothing);
      expect(find.text('Could not load the contacts'), findsOneWidget);

      h.repository.failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
    });
  });

  group('emergency sheet', () {
    testWidgets('a vet edited from the Emergency card shows on every page below', (tester) async {
      // Opened from another tab: the Health tab itself is not on screen.
      await openSheet(tester, kelly);
      await tapVisible(tester, find.byKey(const Key('open-emergency-card')));
      expect(find.text('Emergency card'), findsOneWidget);

      await tapVisible(tester, find.text("Kelly's vets"));
      await tapVisible(tester, find.byKey(const ValueKey('edit-vet-regular')));
      await tester.enterText(find.byKey(const Key('vet-name')), 'Riverside Vets');
      await tapVisible(tester, find.text('Save vet'));
      expect(find.text('Riverside Vets'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Emergency card'), findsOneWidget);
      // The card lists no contacts; the sheet, opened again, has the new name.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EmergencyButton));
      await tester.pumpAndSettle();
      expect(find.text('Riverside Vets'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leads with one Call now for the 24 h vet; the others are rows', (tester) async {
      final h = await openSheet(tester, kelly);
      final primary = find.byKey(const Key('emergency-primary'));
      final rows = find.byKey(const Key('emergency-rows'));

      expect(find.text('Kelly · Emergency'), findsOneWidget);
      expect(find.text('Call first. The rows below help you decide and prepare.'), findsOneWidget);
      // One obvious action: the emergency vet, on one peach card.
      expect(tester.widget<HealthCard>(primary).color, AppColors.peach);
      expect(find.text('Call now'), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.text('EMERGENCY VET (24 H)')), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.text('City Animal Hospital')), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.text('80 Harbour Road, Tel Aviv')), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.text('Call to confirm they are open')), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.byKey(const ValueKey('call-emergency'))), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.byKey(const ValueKey('map-emergency'))), findsOneWidget);
      expect(find.byTooltip('Directions'), findsOneWidget);
      // Each contact once: no Message for the first contact.
      expect(find.byKey(const ValueKey('message-emergency')), findsNothing);
      expect(find.text('Message'), findsNothing);

      // The regular vet and Dana: a row each, with round Message and Call.
      expect(find.descendant(of: rows, matching: find.text('REGULAR VET')), findsOneWidget);
      expect(find.descendant(of: rows, matching: find.text('Dr. Levi, Park Vet Clinic')), findsOneWidget);
      expect(find.descendant(of: rows, matching: find.text('EMERGENCY CONTACT')), findsOneWidget);
      expect(find.descendant(of: rows, matching: find.text('Dana (sister)')), findsOneWidget);
      for (final name in ['Dr. Levi, Park Vet Clinic', 'Dana (sister)']) {
        expect(find.byTooltip('Call $name'), findsOneWidget, reason: name);
        expect(find.byTooltip('Message $name'), findsOneWidget, reason: name);
      }
      expect(find.byKey(const ValueKey('call-regular')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-contact')), findsOneWidget);
      expect(find.text('Call'), findsNothing);
      expect(find.text('Map'), findsNothing);
      expect(find.byKey(const ValueKey('map-regular')), findsNothing);
      expect(find.byKey(const ValueKey('map-contact')), findsNothing);
      // Every row has its health disc: two contacts and five tools.
      expect(find.descendant(of: rows, matching: find.byType(AreaDisc)), findsNWidgets(7));

      // The tools, in order, and the one line of fine print.
      expect(find.text('Is it urgent?'), findsOneWidget);
      expect(find.text('Can Kelly eat this?'), findsOneWidget);
      expect(find.text('Lost mode'), findsOneWidget);
      expect(find.text('Tell people nearby and share a card'), findsOneWidget);
      expect(find.text('Kelly is lost'), findsNothing);
      expect(find.text('Emergency card and kit'), findsOneWidget);
      expect(find.text('3 of 6 kit items · share as PDF'), findsOneWidget);
      expect(find.text('Find a clinic nearby'), findsOneWidget);
      expect(find.text('Emergency clinics near you'), findsOneWidget);
      const fine = 'Lists and signs are general guidance, not a diagnosis. When in doubt, call.';
      expect(find.text(fine), findsOneWidget);
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('Lost mode'), lessThan(top('Emergency card and kit')));
      expect(top('Emergency card and kit'), lessThan(top('Find a clinic nearby')));
      expect(top('Find a clinic nearby'), lessThan(top(fine)));
      expect(top('Call now'), lessThan(tester.getTopLeft(rows).dy));

      // Call now dials the emergency vet; Directions opens its address.
      await tapVisible(tester, find.text('Call now'));
      expect(h.launcher.calls, hasLength(1));
      expect(h.launcher.calls.single.action, ContactAction.call);
      expect(h.launcher.calls.single.target, '+972 3 555 0199');

      await tapVisible(tester, find.byKey(const ValueKey('map-emergency')));
      expect(h.launcher.calls.last.action, ContactAction.map);
      expect(h.launcher.calls.last.target, '80 Harbour Road, Tel Aviv');

      // A row's round Call dials that contact.
      await tapVisible(tester, find.byTooltip('Call Dr. Levi, Park Vet Clinic'));
      expect(h.launcher.calls.last.action, ContactAction.call);
      expect(h.launcher.calls.last.target, parkPhone);
    });

    testWidgets('the safety tools open their pages', (tester) async {
      await openSheet(tester, kelly);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(find.text('Is it urgent?'), findsOneWidget);
      expect(find.text('Signs that mean going to the vet now'), findsOneWidget);
      expect(find.text('Can Kelly eat this?'), findsOneWidget);
      expect(find.text('Foods and plants: safe, a little or dangerous'), findsOneWidget);
      expect(find.text('Tell people nearby and share a card'), findsOneWidget);
      // After the contacts, before Lost mode.
      expect(top('Dana (sister)'), lessThan(top('Is it urgent?')));
      expect(top('Is it urgent?'), lessThan(top('Can Kelly eat this?')));
      expect(top('Can Kelly eat this?'), lessThan(top('Lost mode')));

      await tapVisible(tester, find.text('Is it urgent?'));
      expect(find.text('Any of these means going to a vet now. Call on the way.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Can Kelly eat this?'));
      expect(find.text('Search a food or a plant'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Lost mode'));
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('without the safety capabilities the lists are hidden and Lost mode makes a card', (tester) async {
      final access = FakeAccessRepository();
      access.groups['standard']!
        ..remove('safety.lists')
        ..remove('safety.lost');
      final h = HealthHarness();
      h.extraOverrides.add(accessRepositoryProvider.overrideWithValue(access));
      await openSheet(tester, kelly, harness: h);

      expect(find.text('Is it urgent?'), findsNothing);
      expect(find.text('Can Kelly eat this?'), findsNothing);
      expect(find.text('Make a card to share'), findsOneWidget);
      await tapVisible(tester, find.text('Lost mode'));
      expect(find.text('Kelly is lost'), findsWidgets);
    });

    testWidgets('an open alert turns the Lost mode row into the missing pet', (tester) async {
      final h = HealthHarness();
      final alert = await real(
        tester,
        () => h.lostAlerts.start(
          LostStart(petId: kelly, localityCode: 'raanana', seenAt: fixedNow.subtract(const Duration(hours: 2))),
        ),
      );
      h.lostAlerts.addSighting(alert.id);
      h.lostAlerts.addSighting(alert.id);
      await openSheet(tester, kelly, harness: h);
      expect(find.text('Kelly is missing · 2 sightings'), findsOneWidget);
      expect(find.text('Last seen Today · 15:40'), findsOneWidget);
      expect(find.text('Lost mode'), findsNothing);
      await tapVisible(tester, find.byKey(const Key('emergency-lost')));
      expect(find.byKey(const Key('lost-alert-status')), findsOneWidget);
      expect(find.text('Kelly is home'), findsOneWidget);
    });

    testWidgets('the Emergency card and kit row opens the card', (tester) async {
      await openSheet(tester, kelly);
      await tapVisible(tester, find.text('Emergency card and kit'));
      expect(find.text('Emergency card'), findsOneWidget);
      expect(find.text('Kelly · Emergency'), findsNothing);
    });

    testWidgets('with only a regular vet, the regular vet leads', (tester) async {
      final h = HealthHarness();
      await real(tester, () => h.repository.saveProfile(const HealthProfile(petId: soya, regularVetId: 'v-park')));
      await openSheet(tester, soya, harness: h);
      final primary = find.byKey(const Key('emergency-primary'));

      expect(find.text('Call now'), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.text('REGULAR VET')), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.text('Dr. Levi, Park Vet Clinic')), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.byKey(const ValueKey('call-regular'))), findsOneWidget);
      expect(find.byKey(const Key('emergency-other-contacts')), findsNothing);
      expect(find.byKey(const Key('add-vet-prompt')), findsNothing);

      await tapVisible(tester, find.text('Call now'));
      expect(h.launcher.calls.single.target, parkPhone);
    });

    testWidgets('with only an emergency contact, the contact leads and a vet is asked for', (tester) async {
      final h = HealthHarness();
      await real(
        tester,
        () => h.repository.saveProfile(
          const HealthProfile(petId: soya, contactName: 'Noa', contactPhone: '050 111 2222'),
        ),
      );
      await openSheet(tester, soya, harness: h);
      final primary = find.byKey(const Key('emergency-primary'));

      expect(find.descendant(of: primary, matching: find.text('EMERGENCY CONTACT')), findsOneWidget);
      expect(find.descendant(of: primary, matching: find.text('Noa')), findsOneWidget);
      // A person: no address, no Directions, no opening hours to confirm.
      expect(find.byTooltip('Directions'), findsNothing);
      expect(find.text('Call to confirm they are open'), findsNothing);
      expect(find.byKey(const ValueKey('message-contact')), findsNothing);
      expect(find.byKey(const Key('add-vet-prompt')), findsOneWidget);
      expect(find.text("Add Soya's vet"), findsOneWidget);

      await tapVisible(tester, find.text('Call now'));
      expect(h.launcher.calls.single.target, '050 111 2222');
    });

    testWidgets('with nothing saved, the add-a-vet prompt takes the place of Call now', (tester) async {
      await openSheet(tester, soya);

      expect(find.text('No vet saved for Soya yet'), findsOneWidget);
      expect(find.byKey(const Key('add-new-vet')), findsOneWidget);
      expect(find.text('Call now'), findsNothing);
      expect(find.byKey(const Key('emergency-primary')), findsNothing);
      // The rows below still lead on.
      expect(find.text('Find a clinic nearby'), findsOneWidget);
      expect(find.text('Emergency card and kit'), findsOneWidget);
      expect(find.text('Lost mode'), findsOneWidget);
      expect(find.text('Lists and signs are general guidance, not a diagnosis. When in doubt, call.'), findsOneWidget);
    });

    testWidgets('the Emergency card has no contact list and one Share', (tester) async {
      await openSheet(tester, kelly);
      await tapVisible(tester, find.byKey(const Key('open-emergency-card')));
      expect(find.text('Emergency card'), findsOneWidget);

      // Who to call is on the sheet only.
      for (final tag in ['regular', 'emergency', 'contact']) {
        expect(find.byKey(ValueKey('call-$tag')), findsNothing, reason: tag);
        expect(find.byKey(ValueKey('message-$tag')), findsNothing, reason: tag);
        expect(find.byKey(ValueKey('map-$tag')), findsNothing, reason: tag);
      }
      expect(find.text('Dana (sister)'), findsNothing);
      expect(find.text('Call now'), findsNothing);
      // Share once, in the header.
      expect(find.byTooltip('Share summary'), findsOneWidget);
      expect(find.byKey(const Key('share-summary')), findsNothing);
      expect(find.text('Share summary'), findsNothing);
      // The rest stays.
      expect(find.text('Microchip'), findsOneWidget);
      expect(find.text('Allergies'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('open-emergency-kit')));
      expect(find.byKey(const Key('open-lost-card')), findsOneWidget);
      expect(find.text("Kelly's vets"), findsOneWidget);
      expect(find.textContaining('does not replace veterinary advice'), findsOneWidget);
    });

    testWidgets('Message pre-fills the essentials and the owner sends it', (tester) async {
      final h = await openSheet(tester, kelly);

      await tapVisible(tester, find.byKey(const ValueKey('message-regular')));
      expect(find.text('Message to Dr. Levi, Park Vet Clinic'), findsOneWidget);
      expect(find.text("Hello, this is Alex, Kelly's owner."), findsOneWidget);
      expect(find.text('Kelly: dog, Mix, 13.6 years, 23 kg'), findsOneWidget);
      expect(find.text('Allergies: Chicken (skin reaction)'), findsOneWidget);
      expect(find.text('Conditions: Arthritis in the hips'), findsOneWidget);
      expect(find.text('Medicines: Joint tablets 50 mg, 1 tablet by mouth, twice a day with food'), findsOneWidget);
      expect(find.text('Microchip: 985 112 004 567 321'), findsOneWidget);
      expect(find.textContaining('Nothing is sent until you press send'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('message-what')), 'Kelly has been vomiting since this morning.');
      await tester.pumpAndSettle();
      // Any line can be left out.
      await tapVisible(tester, find.byKey(const ValueKey('remove-line-microchip')));
      expect(find.text('Microchip: 985 112 004 567 321'), findsNothing);

      // Nothing was sent or opened so far.
      expect(h.launcher.calls, isEmpty);

      await tapVisible(tester, find.text('Open in Messages'));
      final sent = h.launcher.calls.single;
      expect(sent.action, ContactAction.textMessage);
      expect(sent.target, parkPhone);
      expect(sent.body, startsWith("Hello, this is Alex, Kelly's owner.\nKelly has been vomiting since this morning."));
      expect(sent.body, contains('Allergies: Chicken (skin reaction)'));
      expect(sent.body, contains('Medicines: Joint tablets 50 mg'));
      expect(sent.body, isNot(contains('Microchip')));
      // The message sheet closed; the emergency sheet is still there.
      expect(find.text('Message to Dr. Levi, Park Vet Clinic'), findsNothing);
      expect(find.text('Kelly · Emergency'), findsOneWidget);
    });

    testWidgets('WhatsApp is offered only for numbers marked as WhatsApp', (tester) async {
      final h = await openSheet(tester, kelly);

      await tapVisible(tester, find.byKey(const ValueKey('message-contact')));
      expect(find.text('Message to Dana (sister)'), findsOneWidget);
      expect(find.text('Open in WhatsApp'), findsNothing);
      Navigator.of(tester.element(find.text('Message to Dana (sister)'))).pop();
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const ValueKey('message-regular')));
      await tapVisible(tester, find.text('Open in WhatsApp'));
      expect(h.launcher.calls.single.action, ContactAction.whatsApp);
      expect(h.launcher.calls.single.target, parkPhone);
      expect(h.launcher.calls.single.body, contains("Kelly's owner"));
    });

    testWidgets('says so when the phone cannot open the other app', (tester) async {
      final h = await openSheet(tester, kelly);
      h.launcher.succeeds = false;

      await tapVisible(tester, find.byKey(const ValueKey('call-regular')));
      expect(find.text('Could not open the phone app'), findsOneWidget);
      expect(find.text('Copy number'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Kelly · Emergency'), findsOneWidget);
    });

    testWidgets('with no vet yet, a saved vet is reused with one tap', (tester) async {
      final h = await openSheet(tester, soya);

      expect(find.text('No vet saved for Soya yet'), findsOneWidget);
      expect(find.text('Use a vet you already saved'), findsOneWidget);
      expect(find.byKey(const ValueKey('call-regular')), findsNothing);

      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));
      expect(find.text('No vet saved for Soya yet'), findsNothing);
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('call-regular')));
      expect(h.launcher.calls.single.target, parkPhone);
      expect((await real(tester, () => h.repository.fetchProfile(soya))).regularVetId, 'v-park');
      // The dot on the button is gone now.
      expect(find.byKey(const Key('emergency-dot')), findsNothing);
    });

    testWidgets('with no vet yet, a new vet can be added with validation', (tester) async {
      final h = await openSheet(tester, soya);

      await tapVisible(tester, find.byKey(const Key('add-new-vet')));
      expect(find.text('Add a vet'), findsOneWidget);

      // The name is required; WhatsApp needs the country code.
      await tester.enterText(find.byKey(const Key('vet-phone')), '03 555 0777');
      await tapVisible(tester, find.byKey(const Key('vet-whatsapp')));
      await tapVisible(tester, find.text('Save vet'));
      expect(find.text('Enter the name of the vet or the clinic.'), findsOneWidget);
      expect(find.text('For WhatsApp, start with the country code, like +972.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('vet-name')), 'Green Street Vets');
      await tester.enterText(find.byKey(const Key('vet-phone')), '+972 3 555 0777');
      await tester.enterText(find.byKey(const Key('vet-address')), '5 Green Street');
      await tapVisible(tester, find.text('Save vet'));

      // Back on the sheet, now with the new vet and its actions.
      expect(find.text('Add a vet'), findsNothing);
      expect(find.text('Green Street Vets'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('call-regular')));
      expect(h.launcher.calls.single.target, '+972 3 555 0777');

      final vets = await real(tester, h.repository.fetchVets);
      final added = vets.firstWhere((v) => v.name == 'Green Street Vets');
      expect(added.onWhatsApp, isTrue);
      expect((await real(tester, () => h.repository.fetchProfile(soya))).regularVetId, added.id);
    });

    testWidgets('a vet without a phone number asks for one instead of Call', (tester) async {
      final h = HealthHarness();
      await real(tester, () async {
        final vet = await h.repository.saveVet(const Vet(id: '', name: 'Hill Clinic', address: '1 Hill Road'));
        await h.repository.saveProfile(HealthProfile(petId: soya, regularVetId: vet.id));
      });
      await openSheet(tester, soya, harness: h);

      expect(find.text('Hill Clinic'), findsOneWidget);
      expect(find.byKey(const ValueKey('call-regular')), findsNothing);
      expect(find.byKey(const ValueKey('add-phone-regular')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-regular')), findsOneWidget);
      // Nothing to call yet, so the button still carries its dot.
      expect(find.byKey(const Key('emergency-dot')), findsOneWidget);
    });

    testWidgets('the one-tap call dials the 24 h clinic first, or asks for a vet', (tester) async {
      final h = await pumpHealthHost(tester, onCoral(kelly));
      final context = tester.element(find.byType(EmergencyButton));

      bool? dialled;
      unawaited(callPrimaryEmergencyContact(context, kelly).then((value) => dialled = value));
      await tester.pumpAndSettle();
      expect(dialled, isTrue);
      expect(h.launcher.calls.single.target, '+972 3 555 0199');

      unawaited(callPrimaryEmergencyContact(context, soya));
      await tester.pumpAndSettle();
      expect(find.text('No vet saved for Soya yet'), findsOneWidget);
      expect(h.launcher.calls, hasLength(1));
    });
  });

  group('pieces for the add-a-pet flow', () {
    testWidgets('the vet tile prompts, then shows the chosen vet', (tester) async {
      final h = await pumpHealthHost(tester, const PetVetTile(petId: soya));

      expect(find.text('Add a vet'), findsOneWidget);
      await tester.tap(find.text('Add a vet'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the regular vet'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-city')));
      expect(find.text('Choose the regular vet'), findsNothing);
      expect(find.text('City Animal Hospital'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect((await real(tester, () => h.repository.fetchProfile(soya))).regularVetId, 'v-city');
    });

    testWidgets('the vet picker goes straight to the form when nothing is saved', (tester) async {
      final h = HealthHarness(repository: fakeHealth(seeded: false));
      await pumpHealthHost(tester, const PetVetTile(petId: soya), harness: h);

      await tester.tap(find.text('Add a vet'));
      await tester.pumpAndSettle();
      expect(find.text('Save vet'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('vet-name')), 'First Vet');
      await tapVisible(tester, find.text('Save vet'));
      expect(find.text('First Vet'), findsOneWidget);
      expect(find.text('No phone number yet'), findsOneWidget);
    });

    testWidgets('the health basics accept "none known" as an answer', (tester) async {
      HealthProfile? saved;
      final h = await pumpHealthHost(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: HealthBasicsSection(petId: soya, saveLabel: 'Next', onSaved: (p) => saved = p),
        ),
      );
      expect((await settled(tester, healthCriticalItemsProvider(soya))).value, HealthCriticalItem.values);

      await tapVisible(tester, find.byKey(const Key('profile-not-chipped')));
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await tester.enterText(find.byKey(const Key('profile-conditions')), 'Heart murmur\nSensitive stomach');
      await tapVisible(tester, find.text('Next'));

      expect(saved, isNotNull);
      expect(saved!.microchip, isEmpty);
      expect(saved!.notChipped, isTrue);
      expect(saved!.microchipAnswered, isTrue);
      expect(saved!.allergies, isEmpty);
      expect(saved!.allergiesNoneKnown, isTrue);
      expect(saved!.allergiesAnswered, isTrue);
      expect(saved!.conditions, ['Heart murmur', 'Sensitive stomach']);
      expect((await real(tester, () => h.repository.fetchProfile(soya))).conditions, hasLength(2));

      // Only the vet's phone number is still missing.
      expect((await settled(tester, healthCriticalItemsProvider(soya))).value, [HealthCriticalItem.vetPhone]);
      expect(HealthCriticalItem.vetPhone.promptFor('Soya'), "Add a phone number for Soya's vet");
    });

    testWidgets('nothing is missing for Kelly, and a load error is not "missing"', (tester) async {
      final h = await pumpHealthHost(tester, const SizedBox());
      expect((await settled(tester, healthCriticalItemsProvider(kelly))).value, isEmpty);

      h.repository.failing = true;
      final state = await settled(tester, healthCriticalItemsProvider(soya));
      expect(state.hasError, isTrue);
      expect(emergencyErrorMessage(state.error!), contains('Could not reach the server'));
    });

    testWidgets("a pet's stored files are noted before the pet is deleted and removed after", (tester) async {
      final h = await pumpHealthHost(tester, const SizedBox(height: 10));
      expect(await real(tester, () => h.repository.fetchDocuments(kelly)), hasLength(4));

      final prepare = hostContainer(tester).read(prepareHealthFilesRemovalProvider);
      final removeFiles = await real(tester, () => prepare(kelly));
      // Getting ready removes nothing: the pet may still fail to delete.
      expect(await real(tester, () => h.repository.fetchDocuments(kelly)), hasLength(4));

      await real(tester, removeFiles);
      expect(await real(tester, () => h.repository.fetchDocuments(kelly)), isEmpty);
      // The records themselves are the database's business, not this call's.
      expect(await real(tester, () => h.repository.fetchRecords(kelly)), isNotEmpty);
    });

    testWidgets('a missing item opens the place where it is filled in', (tester) async {
      await pumpHealthHost(tester, const SizedBox(height: 10));
      final context = tester.element(find.byType(SizedBox).first);

      unawaited(openHealthCriticalItem(context, petId: soya, item: HealthCriticalItem.allergies));
      await tester.pumpAndSettle();
      expect(find.text("Soya's health profile"), findsOneWidget);
      expect(find.byKey(const Key('profile-contact-name')), findsOneWidget);
    });
  });

  group('contacts and links', () {
    testWidgets('the contacts value tells "has a number" from "nothing saved"', (tester) async {
      await pumpHealthHost(tester, const SizedBox());
      final k = (await settled(tester, emergencyContactsProvider(kelly))).value!;
      expect(k.isEmpty, isFalse);
      expect(k.hasPhone, isTrue);
      // The 24 h clinic first, as the Emergency sheet leads with it.
      expect(k.primaryPhone, '+972 3 555 0199');
      expect(k.primaryName, 'City Animal Hospital');
      expect(k.regularVet!.onWhatsApp, isTrue);
      expect(k.emergencyVet!.address, '80 Harbour Road, Tel Aviv');
      expect(k.contact!.name, 'Dana (sister)');

      final s = (await settled(tester, emergencyContactsProvider(soya))).value!;
      expect(s.isEmpty, isTrue);
      expect(s.hasPhone, isFalse);
      expect(s.primaryPhone, isNull);
    });

    test('links carry the number, the text and the address', () {
      expect(telUri('+972 3 555 0142').toString(), 'tel:+97235550142');
      expect(dialable('(03) 555-0142'), '035550142');
      final sms = smsUri('+972 3 555 0142', 'Hello & welcome\nKelly');
      expect(sms.scheme, 'sms');
      expect(sms.path, '+97235550142');
      expect(sms.queryParameters['body'], 'Hello & welcome\nKelly');
      final wa = whatsAppUri('+972 3 555 0142', 'Kelly is unwell');
      expect(wa.host, 'wa.me');
      expect(wa.path, '/97235550142');
      expect(wa.queryParameters['text'], 'Kelly is unwell');
      final map = mapUri('12 Park Street, Tel Aviv');
      expect(map.queryParameters['query'], '12 Park Street, Tel Aviv');
    });
  });
}
