import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/config/app_config.dart';
import 'package:pet_companion/features/auth/widgets/account_sheet.dart';
import 'package:pet_companion/features/auth/widgets/delete_account_dialog.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/platform/link_opener.dart';
import 'package:pet_companion/widgets/legal_notice.dart';

import 'helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('starts signed out on the login screen', (tester) async {
    await pumpApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Feeding'), findsNothing);
  });

  testWidgets('validates email and password before submitting', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('That does not look like an email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('wrong password shows an error and stays on login', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).at(0), FakeAuthRepository.demoEmail);
    await tester.enterText(find.byType(TextFormField).at(1), 'definitely-wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password. Please try again.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('demo sign in reaches home, sign out returns to login', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);

    expect(find.text('Feeding'), findsOneWidget);
    expect(find.text('A'), findsOneWidget); // avatar initial of the demo user

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text(FakeAuthRepository.demoEmail), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('sign up creates an account and lands on the first-pet welcome', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Limor');
    await tester.enterText(find.byType(TextFormField).at(1), 'limor@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'walkies123');
    await tester.enterText(find.byType(TextFormField).at(3), 'walkies123');
    // The form runs past the banner and the screen: scrolled to, as by hand.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    // A new account has no pet yet: the first-pet welcome stands in for
    // the tabs until one is added.
    expect(find.text('Welcome, Limor'), findsOneWidget);
    expect(find.text('Add my first pet'), findsOneWidget);
    expect(find.text('Feeding'), findsNothing);
  });

  testWidgets('deleting the account asks for the word, then returns to login for good', (tester) async {
    final en = lookupAppL10n(englishLocale);
    await pumpApp(tester);
    await signInAsDemo(tester);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(AccountSheet.deleteAccountKey));
    await tester.tap(find.byKey(AccountSheet.deleteAccountKey));
    await tester.pumpAndSettle();
    expect(find.text(en.accountDeleteTitle), findsOneWidget);
    FilledButton confirm() =>
        tester.widget<FilledButton>(find.byKey(DeleteAccountDialog.confirmKey));
    expect(confirm().enabled, isFalse, reason: 'nothing typed yet');

    await tester.enterText(find.byKey(DeleteAccountDialog.fieldKey), 'nope');
    await tester.pump();
    expect(confirm().enabled, isFalse, reason: 'the wrong word');

    await tester.enterText(find.byKey(DeleteAccountDialog.fieldKey), ' delete ');
    await tester.pump();
    expect(confirm().enabled, isTrue, reason: 'case and spaces do not matter');
    await tester.tap(find.byKey(DeleteAccountDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text(en.accountDeleted), findsOneWidget);

    // The account is really gone.
    await signInAsDemo(tester);
    expect(find.text(en.authErrNoAccount), findsOneWidget);
  });

  testWidgets('cancelling the deletion keeps the account', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(AccountSheet.deleteAccountKey));
    await tester.tap(find.byKey(AccountSheet.deleteAccountKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeleteAccountDialog.cancelKey));
    await tester.pumpAndSettle();

    expect(find.byKey(DeleteAccountDialog.fieldKey), findsNothing);
    expect(find.text(FakeAuthRepository.demoEmail), findsOneWidget, reason: 'the sheet is still open');
  });

  testWidgets('the sign-up notice links to the Terms of Use and the Privacy Policy', (tester) async {
    final opener = RecordingLinkOpener();
    await pumpApp(tester, overrides: [linkOpenerProvider.overrideWithValue(opener)]);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    await tester.ensureVisible(find.byKey(LegalNotice.termsKey));
    await tester.tap(find.byKey(LegalNotice.termsKey));
    await tester.tap(find.byKey(LegalNotice.privacyKey));
    await tester.pump();

    expect(opener.opened, [AppConfig.termsUrl('en'), AppConfig.privacyUrl('en')]);
    expect(opener.opened[0].toString(), endsWith('/legal/terms.html'));
    expect(opener.opened[1].toString(), endsWith('/legal/privacy.html'));
  });

  testWidgets('in Hebrew the sign-up notice opens the Hebrew pages', (tester) async {
    final he = lookupAppL10n(hebrewLocale);
    final opener = RecordingLinkOpener();
    await pumpApp(
      tester,
      language: AppLanguage.hebrew,
      overrides: [linkOpenerProvider.overrideWithValue(opener)],
    );
    await tester.tap(find.text(he.authCreateAnAccount));
    await tester.pumpAndSettle();

    expect(find.text(he.legalTerms), findsOneWidget);
    expect(find.text(he.legalPrivacy), findsOneWidget);
    await tester.ensureVisible(find.byKey(LegalNotice.privacyKey));
    await tester.tap(find.byKey(LegalNotice.privacyKey));
    await tester.pump();

    expect(opener.opened.single.toString(), endsWith('/legal/privacy.he.html'));
  });

  testWidgets('sign up rejects an email that is already registered', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Someone');
    await tester.enterText(find.byType(TextFormField).at(1), FakeAuthRepository.demoEmail);
    await tester.enterText(find.byType(TextFormField).at(2), 'walkies123');
    await tester.enterText(find.byType(TextFormField).at(3), 'walkies123');
    // The form runs past the banner and the screen: scrolled to, as by hand.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('An account with that email already exists.'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });
}
