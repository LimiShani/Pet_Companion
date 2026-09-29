import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';

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

  testWidgets('sign up creates an account and lands on home', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Limor');
    await tester.enterText(find.byType(TextFormField).at(1), 'limor@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'walkies123');
    await tester.enterText(find.byType(TextFormField).at(3), 'walkies123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Feeding'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
  });

  testWidgets('sign up rejects an email that is already registered', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Someone');
    await tester.enterText(find.byType(TextFormField).at(1), FakeAuthRepository.demoEmail);
    await tester.enterText(find.byType(TextFormField).at(2), 'walkies123');
    await tester.enterText(find.byType(TextFormField).at(3), 'walkies123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('An account with that email already exists.'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });
}
