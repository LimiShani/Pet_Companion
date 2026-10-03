import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/findvet/findvet.dart';
import 'package:pet_companion/features/settings/side_menu.dart';

import '../helpers.dart';
import 'findvet_test_helpers.dart';

// A directory reviewer attaches an extra Google listing to a facility we
// hold (a hospital with a building pin and a street pin), from the results
// or from a "possible listing match" review item.

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Signs in as the demo user and opens the emergency results near Rehovot.
  Future<void> openEmergencyResults(WidgetTester tester, FindVetKit kit) async {
    await pumpApp(tester, overrides: kit.overrides, size: tallPhone);
    await signInAsDemo(tester);
    await tester.tap(find.byTooltip(appEn.homeMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppSideMenu.findVetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FindVetScreen.emergencyChoiceKey));
    await tester.pumpAndSettle();
    await pickPlace(tester, 'Rehov', 'Rehovot');
  }

  testWidgets('a reviewer sees "Link" only on listings that came only from Google', (tester) async {
    final kit = FindVetKit(admin: true);
    await openEmergencyResults(tester, kit);

    expect(find.byKey(VetResultCard.linkKey(demoListing)), findsOneWidget);
    expect(find.byKey(VetResultCard.linkKey(demoFamilyVet)), findsOneWidget);
    // Directory records (linked or not) have nothing to link.
    expect(find.byKey(VetResultCard.linkKey(demoCentre)), findsNothing);
    expect(find.byKey(VetResultCard.linkKey(demoHospital)), findsNothing);
  });

  testWidgets('nobody else sees it: not a signed-in owner, not without an account', (tester) async {
    final kit = FindVetKit();
    await openEmergencyResults(tester, kit);
    expect(find.text(en.adminLinkAction), findsNothing);
  });

  testWidgets('not shown on the sign-in screen path either', (tester) async {
    final kit = FindVetKit(admin: true);
    await openEmergencySignedOut(tester, kit);
    await pickPlace(tester, 'Rehov', 'Rehovot');
    expect(find.text(en.adminLinkAction), findsNothing);
  });

  testWidgets('linking: choose the facility, confirm, and the search runs again', (tester) async {
    final kit = FindVetKit(admin: true);
    await openEmergencyResults(tester, kit);
    final searches = kit.repo.requests.length;
    final radius = kit.repo.requests.last.radiusM;

    await tester.tap(find.byKey(VetResultCard.linkKey(demoListing)));
    await tester.pumpAndSettle();
    expect(find.text(en.adminLinkTitle), findsOneWidget);
    expect(find.text(en.adminLinkNote), findsOneWidget);
    // Withdrawn facilities are not offered; the others are.
    expect(find.byKey(const Key('link-listing-facility-demo-2')), findsOneWidget);
    expect(find.byKey(const Key('link-listing-facility-demo-5')), findsOneWidget);

    await tester.tap(find.byKey(const Key('link-listing-facility-demo-2')));
    await tester.pumpAndSettle();
    expect(find.text(en.adminLinkConfirm('Demo Emergency Animal Hospital 24/7', 'Demo Veterinary Hospital')), findsOneWidget);

    await tester.tap(find.byKey(const Key('link-listing-confirm')));
    await tester.pumpAndSettle();
    expect(kit.admin.actions.last, 'link:demo-2:demo-place-3');
    expect(find.text(en.adminLinked), findsOneWidget);
    expect(kit.repo.requests.length, searches + 1, reason: 'searched again to show them as one place');
    expect(kit.repo.requests.last.radiusM, radius);
  });

  testWidgets('cancelling links nothing', (tester) async {
    final kit = FindVetKit(admin: true);
    await openEmergencyResults(tester, kit);
    await tester.tap(find.byKey(VetResultCard.linkKey(demoListing)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('link-listing-facility-demo-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(appEn.commonCancel));
    await tester.pumpAndSettle();
    expect(kit.admin.actions, isEmpty);
  });

  testWidgets('a "possible listing match" item links with one tap and closes', (tester) async {
    final kit = FindVetKit(admin: true);
    kit.admin.items
      ..clear()
      ..add(
        ReviewItem(
          id: 'c1',
          facilityId: 'demo-2',
          facilityName: 'Demo Veterinary Hospital',
          kind: 'link_candidate',
          severity: 'low',
          details: const {'placeId': 'place-near-junction', 'matchedOn': 'phone'},
          createdAt: DateTime(2026, 10, 3),
        ),
      );
    await pumpApp(tester, overrides: kit.overrides, size: tallPhone);
    await signInAsDemo(tester);
    await tester.tap(find.byTooltip(appEn.homeMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppSideMenu.directoryReviewKey));
    await tester.pumpAndSettle();

    expect(find.text(en.adminKindLinkCandidate), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-link-c1')));
    await tester.pumpAndSettle();
    expect(kit.admin.actions.single, 'link:demo-2:place-near-junction');
    expect(find.text(en.adminKindLinkCandidate), findsNothing);
    expect(find.text(en.adminNoItems), findsOneWidget);
  });

  testWidgets('other review items have no Link button', (tester) async {
    final kit = FindVetKit(admin: true);
    await pumpApp(tester, overrides: kit.overrides, size: tallPhone);
    await signInAsDemo(tester);
    await tester.tap(find.byTooltip(appEn.homeMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppSideMenu.directoryReviewKey));
    await tester.pumpAndSettle();
    expect(find.text(en.adminLink), findsNothing);
  });
}
