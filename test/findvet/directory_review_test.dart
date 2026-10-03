import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/findvet/findvet.dart';
import 'package:pet_companion/features/settings/side_menu.dart';

import '../helpers.dart';
import 'findvet_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> openMenu(WidgetTester tester, FindVetKit kit) async {
    await pumpApp(tester, overrides: kit.overrides, size: tallPhone);
    await signInAsDemo(tester);
    await tester.tap(find.byTooltip(appEn.homeMenu));
    await tester.pumpAndSettle();
  }

  Future<void> answerNote(WidgetTester tester, String note) async {
    await tester.enterText(find.byKey(const Key('review-note')), note);
    await tester.tap(find.byKey(const Key('review-note-ok')));
    await tester.pumpAndSettle();
  }

  testWidgets('the review entry is shown to directory reviewers only', (tester) async {
    await openMenu(tester, FindVetKit());
    expect(find.byKey(AppSideMenu.findVetKey), findsOneWidget);
    expect(find.byKey(AppSideMenu.directoryReviewKey), findsNothing);
  });

  testWidgets('a reviewer resolves items and approves, corrects and withdraws facilities', (tester) async {
    final kit = FindVetKit(admin: true);
    await openMenu(tester, kit);
    await tester.tap(find.byKey(AppSideMenu.directoryReviewKey));
    await tester.pumpAndSettle();
    expect(find.byKey(DirectoryReviewScreen.screenKey), findsOneWidget);

    // The weekly check's findings, most severe first.
    expect(find.text(en.adminKindEmergencyEvidenceMissing), findsOneWidget);
    expect(find.text(en.adminKindPhoneConflict), findsOneWidget);

    await tester.tap(find.byKey(const Key('review-resolve-demo-item-1')));
    await tester.pumpAndSettle();
    await answerNote(tester, 'Called them: night service ended');
    expect(kit.admin.actions.last, 'resolve:demo-item-1:Called them: night service ended');
    expect(find.text(en.adminKindEmergencyEvidenceMissing), findsNothing);

    // Withdraw an emergency designation.
    await tester.tap(find.byKey(const Key('review-withdraw-emergency-demo-4')));
    await tester.pumpAndSettle();
    await answerNote(tester, 'Evidence gone');
    expect(kit.admin.actions.last, 'withdraw:demo-4:emergency');

    // Approve the pending facility.
    await tester.tap(find.byKey(const Key('review-approve-demo-5')));
    await tester.pumpAndSettle();
    await answerNote(tester, 'Checked the website');
    expect(kit.admin.actions.last, 'status:demo-5:approved');

    // Correct a fact: a source link is required.
    await tester.tap(find.byKey(const Key('review-correct-demo-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('review-fact-value')), '24/7');
    await tester.tap(find.byKey(const Key('review-fact-save')));
    await tester.pumpAndSettle();
    expect(find.text(en.adminSourceRequired), findsOneWidget);
    await tester.enterText(find.byKey(const Key('review-fact-source')), 'https://hospital.example/emergency');
    await tester.tap(find.byKey(const Key('review-fact-save')));
    await tester.pumpAndSettle();
    expect(kit.admin.actions.last, 'claim:demo-2:emergency={schedule: 24/7}@https://hospital.example/emergency');
    expect(find.text(en.adminSaved), findsOneWidget);
  });

  testWidgets('the page refuses an account that is not a reviewer', (tester) async {
    final kit = FindVetKit();
    await pumpApp(tester, overrides: kit.overrides);
    await signInAsDemo(tester);
    final context = tester.element(find.byType(Scaffold).first);
    openDirectoryReview(context);
    await tester.pumpAndSettle();
    expect(find.text(en.adminNotAllowed), findsOneWidget);
  });
}
