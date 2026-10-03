import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/findvet/findvet.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/health/emergency/emergency_sheet.dart' show EmergencySheet;
import 'package:pet_companion/features/health/emergency/vet_form_screen.dart';
import 'package:pet_companion/features/settings/side_menu.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';
import 'findvet_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('location', () {
    testWidgets('is asked for only on the tap; a "no" falls back to typing a place', (tester) async {
      final kit = FindVetKit();
      await openEmergencySignedOut(tester, kit);

      // The emergency path opens on "Where should we look?", with the reason.
      expect(find.text(en.areaQuestion), findsOneWidget);
      expect(find.text(en.locationWhy), findsOneWidget);
      expect(kit.location.asked, 0, reason: 'nothing is asked before the owner taps');

      await tester.tap(find.byKey(AreaPicker.useLocationKey));
      await tester.pumpAndSettle();
      expect(kit.location.asked, 1);
      expect(find.text(en.problemDenied), findsOneWidget);
      expect(kit.repo.requests, isEmpty);

      // Manual search still works, and the area shown is the one chosen.
      await pickPlace(tester, 'Rehov', 'Rehovot');
      expect(find.text(en.searchingNear('Rehovot')), findsOneWidget);
      expect(kit.repo.requests.single.mode, VetSearchMode.emergency);
      expect(kit.repo.requests.single.center, const GeoPoint(31.8928, 34.8113));
      expect(kit.repo.requests.single.region, 'IL');
    });

    testWidgets('a fix searches around "your location"; changing the area goes back to the picker', (tester) async {
      final kit = FindVetKit(
        location: const LocationResult(LocationOutcome.found, point: rehovot, accuracyM: 40),
      );
      await openEmergencySignedOut(tester, kit);
      await tester.tap(find.byKey(AreaPicker.useLocationKey));
      await tester.pumpAndSettle();

      expect(find.text(en.searchingNear(en.yourLocation)), findsOneWidget);
      expect(find.text(en.approximateLocation(1)), findsNothing);
      expect(kit.repo.requests.single.center, rehovot);

      await tester.tap(find.byKey(AreaBar.changeKey));
      await tester.pumpAndSettle();
      expect(find.text(en.areaQuestion), findsOneWidget);
    });

    testWidgets('a rough fix says so', (tester) async {
      final kit = FindVetKit(
        location: const LocationResult(LocationOutcome.found, point: rehovot, accuracyM: 3200),
      );
      await openEmergencySignedOut(tester, kit);
      await tester.tap(find.byKey(AreaPicker.useLocationKey));
      await tester.pumpAndSettle();
      expect(find.text(en.approximateLocation(4)), findsOneWidget);
    });

    testWidgets('"never" offers the phone settings and typing', (tester) async {
      final kit = FindVetKit(location: const LocationResult(LocationOutcome.deniedForever));
      await openEmergencySignedOut(tester, kit);
      await tester.tap(find.byKey(AreaPicker.useLocationKey));
      await tester.pumpAndSettle();

      expect(find.text(en.problemDeniedForever), findsOneWidget);
      await tester.tap(find.byKey(AreaPicker.openSettingsKey));
      await tester.pumpAndSettle();
      expect(kit.location.settingsOpened, [LocationOutcome.deniedForever]);
      expect(find.byKey(AreaPicker.fieldKey), findsOneWidget);
    });

    testWidgets('location switched off, or unavailable, is explained', (tester) async {
      final kit = FindVetKit(location: const LocationResult(LocationOutcome.serviceOff));
      await openEmergencySignedOut(tester, kit);
      await tester.tap(find.byKey(AreaPicker.useLocationKey));
      await tester.pumpAndSettle();
      expect(find.text(en.problemServiceOff), findsOneWidget);

      kit.location.result = const LocationResult(LocationOutcome.unavailable);
      await tester.tap(find.byKey(AreaPicker.useLocationKey));
      await tester.pumpAndSettle();
      expect(find.text(en.problemUnavailable), findsOneWidget);
    });

    testWidgets('a place outside Israel is not searched', (tester) async {
      final kit = FindVetKit(
        location: const LocationResult(LocationOutcome.found, point: GeoPoint(51.5, -0.12), accuracyM: 20),
      );
      await openEmergencySignedOut(tester, kit);
      await tester.tap(find.byKey(AreaPicker.useLocationKey));
      await tester.pumpAndSettle();
      expect(find.text(en.problemOutsideRegion), findsOneWidget);
      expect(kit.repo.requests, isEmpty);
    });

    testWidgets('an address goes to the geocoder; nothing found is said', (tester) async {
      final kit = FindVetKit();
      await openEmergencySignedOut(tester, kit);

      await tester.enterText(find.byKey(AreaPicker.fieldKey), 'Herzl 10');
      await tester.tap(find.byKey(AreaPicker.searchKey));
      await tester.pumpAndSettle();
      expect(find.text(en.placeNoMatch), findsOneWidget);

      kit.repo.geocodeResults = const [PlaceMatch(label: 'Herzl 10, Rehovot', point: rehovot)];
      await tester.tap(find.byKey(AreaPicker.searchKey));
      await tester.pumpAndSettle();
      // One answer is used straight away.
      expect(find.text(en.searchingNear('Herzl 10, Rehovot')), findsOneWidget);
    });

    testWidgets('a failed lookup says so and keeps the field', (tester) async {
      final kit = FindVetKit()..repo.failure = VetFinderFailure.offline;
      await openEmergencySignedOut(tester, kit);
      await tester.enterText(find.byKey(AreaPicker.fieldKey), '7610001');
      await tester.tap(find.byKey(AreaPicker.searchKey));
      await tester.pumpAndSettle();
      expect(find.text(en.placeLookupFailed), findsOneWidget);
      expect(find.byKey(AreaPicker.fieldKey), findsOneWidget);
    });
  });

  group('emergency results', () {
    testWidgets('advertised first with a second option, everything else labelled honestly', (tester) async {
      final kit = FindVetKit();
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');

      expect(find.byKey(FindVetScreen.demoBannerKey), findsOneWidget);
      expect(find.text(en.callFirstTitle), findsOneWidget);

      // Two facilities advertising emergency care: nearest and second.
      expect(inCard(demoCentre, en.firstOption), findsOneWidget);
      expect(inCard(demoHospital, en.secondOption), findsOneWidget);
      expect(inCard(demoCentre, en.evidenceAdvertisedSchedule('24/7')), findsOneWidget);
      expect(inCard(demoCentre, en.evidenceSourceChecked('30.09.26')), findsOneWidget);

      // A listing called "Emergency ... 24/7" is only listed nearby.
      expect(inCard(demoListing, en.evidenceListed), findsOneWidget);
      expect(inCard(demoListing, en.evidenceListedNote), findsOneWidget);
      expect(find.descendant(of: cardOf(demoListing), matching: find.textContaining('advertised')), findsNothing);
      expect(inCard(demoListing, en.evidenceOpenNow), findsOneWidget);
      expect(find.text(en.sectionOther), findsOneWidget);

      // A claim whose evidence disappeared: not advertised, and stale.
      expect(inCard(demoNightClinic, en.evidenceUnverified), findsOneWidget);
      expect(inCard(demoNightClinic, en.staleNote('19.08.26')), findsOneWidget);

      // The other practices nearby are listed too, as not confirmed.
      expect(inCard(demoFamilyVet, en.evidenceListed), findsOneWidget);
      expect(cardOf('g:demo-place-6'), findsOneWidget);

      // Nobody is "accepting": every card asks to call and confirm.
      final cards = find.byType(VetResultCard);
      expect(cards, findsNWidgets(6));
      expect(find.text(en.callToConfirm), findsNWidgets(6));
      expect(find.text(en.evidenceAccepting), findsNothing);

      // Call and Directions on each card; no Save without an account.
      for (final key in [demoCentre, demoHospital, demoNightClinic, demoListing]) {
        expect(find.byKey(VetResultCard.callKey(key)), findsOneWidget);
        expect(find.byKey(VetResultCard.directionsKey(key)), findsOneWidget);
        expect(find.byKey(VetResultCard.saveKey(key)), findsNothing);
      }

      // Content from the map provider is credited, as it requires.
      expect(find.text('Google Maps'), findsOneWidget);
    });

    testWidgets('Call opens the dialler at once and confirms nothing', (tester) async {
      final kit = FindVetKit();
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');

      await tester.tap(find.byKey(VetResultCard.callKey(demoCentre)));
      await tester.pumpAndSettle();
      expect(kit.launcher.launched.single.kind, VetLaunch.call);
      expect(kit.launcher.launched.single.target, '000-0000001');
      expect(inCard(demoCentre, en.callToConfirm), findsOneWidget, reason: 'still to be confirmed by the owner');

      await tester.tap(find.byKey(VetResultCard.directionsKey(demoCentre)));
      await tester.pumpAndSettle();
      expect(kit.launcher.launched.last.kind, VetLaunch.directions);
    });

    testWidgets('a dialler that cannot open offers the number to copy', (tester) async {
      final kit = FindVetKit();
      kit.launcher.succeeds = false;
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');
      await tester.tap(find.byKey(VetResultCard.callKey(demoCentre)));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('000-0000001'), findsWidgets);
    });

    testWidgets('a facility with no phone says so instead of Call', (tester) async {
      final kit = FindVetKit()
        ..repo.respond = (request) => VetSearchResult(
          mode: request.mode,
          center: request.center,
          radiusM: request.radiusM,
          searchedAt: testNow,
          attribution: 'Google Maps',
          results: const [
            VetResult(key: 'g:nophone', name: 'Quiet Clinic', location: rehovot, distanceM: 300, fromProvider: true),
          ],
        );
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');
      expect(find.byKey(VetResultCard.callKey('g:nophone')), findsNothing);
      expect(inCard('g:nophone', en.noPhone), findsOneWidget);
      expect(find.byKey(VetResultCard.directionsKey('g:nophone')), findsOneWidget);
    });

    testWidgets('a fresh report from the facility shows; an expired one never does', (tester) async {
      IntakeReport report(Duration validFor) => IntakeReport(
        state: IntakeState.accepting,
        species: const ['dog', 'cat'],
        updatedAt: testNow.subtract(const Duration(minutes: 20)),
        expiresAt: testNow.add(validFor),
      );
      VetResult facility(String key, IntakeReport intake) => VetResult(
        key: key,
        facilityId: key,
        name: key,
        location: rehovot,
        distanceM: 900,
        phone: '000',
        fromCurated: true,
        emergency: EmergencyClaim(
          state: EmergencyClaimState.advertised,
          sourceUrl: 'https://vet.example/$key',
          checkedAt: testNow,
        ),
        intake: intake,
        lastCheckedAt: testNow,
      );
      final kit = FindVetKit()
        ..repo.respond = (request) => VetSearchResult(
          mode: request.mode,
          center: request.center,
          radiusM: request.radiusM,
          searchedAt: testNow,
          results: [
            facility('fresh', report(const Duration(hours: 1))),
            facility('expired', report(const Duration(minutes: -5))),
          ],
        );
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');

      expect(inCard('fresh', en.evidenceAccepting), findsOneWidget);
      expect(inCard('fresh', en.evidenceReported('13:40', '15:00')), findsOneWidget);
      expect(inCard('fresh', en.callToConfirm), findsNothing);
      expect(inCard('expired', en.evidenceAccepting), findsNothing);
      expect(inCard('expired', en.callToConfirm), findsOneWidget);
    });

    testWidgets('live search down: our own emergency records, with their check dates', (tester) async {
      final kit = FindVetKit()..repo.providerStatus = ProviderStatus.error;
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');

      expect(find.text(en.noticeProviderDown), findsOneWidget);
      expect(cardOf(demoCentre), findsOneWidget);
      expect(cardOf(demoHospital), findsOneWidget);
      expect(cardOf(demoListing), findsNothing, reason: 'no provider content when the provider failed');
      expect(inCard(demoHospital, en.evidenceSourceChecked('23.09.26')), findsOneWidget);
      expect(find.text('Google Maps'), findsNothing);
      expect(find.text(en.callToConfirm), findsWidgets);
    });

    testWidgets('a widened search says how far it went', (tester) async {
      final kit = FindVetKit()
        ..repo.respond = (request) => VetSearchResult(
          mode: request.mode,
          center: request.center,
          radiusM: 50000,
          expanded: true,
          notices: const {'radius_expanded'},
          searchedAt: testNow,
          results: [
            VetResult(
              key: 'far',
              facilityId: 'far',
              name: 'Far Hospital',
              location: rehovot,
              distanceM: 41000,
              phone: '000',
              fromCurated: true,
              emergency: EmergencyClaim(
                state: EmergencyClaimState.advertised,
                sourceUrl: 'https://far.example',
                checkedAt: testNow,
              ),
              lastCheckedAt: testNow,
            ),
          ],
        );
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');

      expect(find.text(en.noticeExpanded(50)), findsOneWidget);
      expect(find.text(en.onlyOneAdvertised(50)), findsOneWidget);
      // The widest step is still offered for a second option.
      expect(find.text(en.searchWider(120)), findsOneWidget);
      await tester.tap(find.byKey(FindVetScreen.widerKey));
      await tester.pumpAndSettle();
      expect(kit.repo.requests.last.radiusM, 120000);
    });

    testWidgets('nothing found: wider search and another area are offered', (tester) async {
      final kit = FindVetKit()
        ..repo.respond = (request) => VetSearchResult(
          mode: request.mode,
          center: request.center,
          radiusM: request.radiusM,
          notices: const {'no_results'},
          searchedAt: testNow,
          results: const [],
        );
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');

      expect(find.text(en.noResultsTitle), findsOneWidget);
      expect(find.text(en.noEmergencyResultsBody(10)), findsOneWidget);
      await tester.tap(find.byKey(FindVetScreen.widerKey));
      await tester.pumpAndSettle();
      expect(kit.repo.requests.last.radiusM, 25000);

      await tester.tap(find.byKey(FindVetScreen.otherAreaKey));
      await tester.pumpAndSettle();
      expect(find.byKey(AreaPicker.fieldKey), findsOneWidget);
    });

    testWidgets('a failed search explains and retries', (tester) async {
      final kit = FindVetKit()..repo.failure = VetFinderFailure.offline;
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');
      expect(find.text(en.errorOffline), findsOneWidget);

      kit.repo.failure = null;
      await tester.tap(find.byKey(FindVetScreen.retryKey));
      await tester.pumpAndSettle();
      expect(cardOf(demoCentre), findsOneWidget);
    });

    testWidgets('too many searches is its own message', (tester) async {
      final kit = FindVetKit()..repo.failure = VetFinderFailure.rateLimited;
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');
      expect(find.text(en.errorRateLimited), findsOneWidget);
    });

    testWidgets('the labels are explained', (tester) async {
      final kit = FindVetKit();
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');
      await tester.ensureVisible(find.byKey(FindVetScreen.legendKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FindVetScreen.legendKey));
      await tester.pumpAndSettle();
      expect(find.text(en.legendAcceptingBody), findsOneWidget);
      expect(find.text(en.legendCallBody), findsOneWidget);
    });
  });

  group('choosing a path', () {
    testWidgets('from the side menu: choice, long term results, Save as a pet\'s regular vet', (tester) async {
      final kit = FindVetKit(
        location: const LocationResult(LocationOutcome.found, point: rehovot, accuracyM: 25),
      );
      await pumpApp(tester, overrides: kit.overrides, size: tallPhone);
      await signInAsDemo(tester);
      await tester.tap(find.byTooltip(appEn.homeMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppSideMenu.findVetKey));
      await tester.pumpAndSettle();

      // The first screen offers both paths and asks for nothing.
      expect(find.byKey(FindVetScreen.emergencyChoiceKey), findsOneWidget);
      expect(find.byKey(FindVetScreen.longTermChoiceKey), findsOneWidget);
      expect(kit.location.asked, 0);

      await tester.tap(find.byKey(FindVetScreen.longTermChoiceKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AreaPicker.useLocationKey));
      await tester.pumpAndSettle();
      expect(kit.repo.requests.single.mode, VetSearchMode.longTerm);
      expect(kit.repo.requests.single.radiusM, 5000);

      // Long term: practices, with species only where sourced, no emergency
      // banner, and Save.
      expect(find.text(en.callFirstTitle), findsNothing);
      expect(inCard(demoCentre, en.speciesLine('dogs, cats')), findsOneWidget);
      expect(find.descendant(of: cardOf(demoFamilyVet), matching: find.textContaining('Treats')), findsNothing);
      expect(inCard(demoFamilyVet, en.evidenceClosedNow), findsOneWidget);
      expect(inCard(demoFamilyVet, en.evidenceListed), findsOneWidget);
      expect(find.byKey(VetResultCard.saveKey(demoFamilyVet)), findsOneWidget);

      // Details: the published week and the place on the map.
      await tester.tap(find.byKey(VetResultCard.detailsKey(demoFamilyVet)));
      await tester.pumpAndSettle();
      expect(inCard(demoFamilyVet, en.hoursTitle), findsOneWidget);
      expect(inCard(demoFamilyVet, 'Saturday: Closed'), findsOneWidget);

      // Save: two pets, so which one; then Health's vet form, filled in.
      await tester.tap(find.byKey(VetResultCard.saveKey(demoFamilyVet)));
      await tester.pumpAndSettle();
      expect(find.text(en.saveChoosePet), findsOneWidget);
      await tester.tap(find.byKey(const Key('findvet-save-pet-kelly')));
      await tester.pumpAndSettle();
      expect(find.byType(VetFormScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Demo Family Vet Clinic'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '000-0000005'), findsOneWidget);

      await tester.ensureVisible(find.text(lookupHealthL10n(englishLocale).saveVet));
      await tester.tap(find.text(lookupHealthL10n(englishLocale).saveVet));
      await tester.pumpAndSettle();
      expect(find.byType(VetFormScreen), findsNothing);
      expect(find.text(en.savedVet), findsOneWidget);

      // Switching path keeps the area and searches again.
      await tester.tap(find.text(en.modeEmergency));
      await tester.pumpAndSettle();
      expect(kit.repo.requests.last.mode, VetSearchMode.emergency);
      expect(kit.location.asked, 1, reason: 'the location is not asked for again');

      // Back from a path returns to the choice, then closes.
      await tester.tap(find.byTooltip(appEn.commonBack));
      await tester.pumpAndSettle();
      expect(find.byKey(FindVetScreen.longTermChoiceKey), findsOneWidget);
      await tester.tap(find.byTooltip(appEn.commonBack));
      await tester.pumpAndSettle();
      expect(find.byKey(FindVetScreen.screenKey), findsNothing);
    });

    testWidgets('the Emergency sheet opens the emergency path', (tester) async {
      final kit = FindVetKit();
      await pumpApp(tester, overrides: kit.overrides);
      await signInAsDemo(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EmergencyButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(EmergencySheet.findVetKey));
      await tester.tap(find.byKey(EmergencySheet.findVetKey));
      await tester.pumpAndSettle();

      expect(find.byKey(FindVetScreen.screenKey), findsOneWidget);
      expect(find.text(en.areaQuestion), findsOneWidget);
      expect(find.byKey(FindVetScreen.emergencyChoiceKey), findsNothing);
    });
  });

  group('Hebrew, right to left', () {
    testWidgets('the emergency path reads right to left with Hebrew labels', (tester) async {
      final kit = FindVetKit();
      await openEmergencySignedOut(tester, kit, language: AppLanguage.hebrew);
      expect(Directionality.of(tester.element(find.byKey(AreaPicker.fieldKey))), TextDirection.rtl);

      await pickPlace(tester, 'רחוב', 'רחובות');
      expect(kit.repo.requests.single.language, 'he');
      expect(find.text(he.callToConfirm), findsNWidgets(6));
      expect(find.text(he.call), findsNWidgets(5), reason: 'one demo place has no phone');
      expect(find.text(he.directions), findsNWidgets(6));
      expect(inCard(demoListing, he.evidenceListed), findsOneWidget);
    });

    testWidgets('fits a small phone with large text', (tester) async {
      final kit = FindVetKit();
      await openEmergencySignedOut(tester, kit, language: AppLanguage.hebrew, textScale: 1.3);
      tester.view.physicalSize = const Size(320, 568) * 3;
      await tester.pumpAndSettle();
      await pickPlace(tester, 'רחוב', 'רחובות');
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('screen readers', () {
    testWidgets('Call and Directions name the facility', (tester) async {
      final semantics = tester.ensureSemantics();
      final kit = FindVetKit();
      await openEmergencySignedOut(tester, kit);
      await pickPlace(tester, 'Rehov', 'Rehovot');
      expect(find.bySemanticsLabel(en.callName('Demo Animal Emergency Centre')), findsOneWidget);
      expect(find.bySemanticsLabel(en.directionsName('Demo Animal Emergency Centre')), findsOneWidget);
      semantics.dispose();
    });
  });
}
