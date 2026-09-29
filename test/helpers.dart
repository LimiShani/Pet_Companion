import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';

/// Pumps the whole app at phone size with a zero-latency fake auth backend.
/// Lands on the login screen.
Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero))],
      child: const PetCompanionApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Signs in with the seeded demo account from the login screen.
Future<void> signInAsDemo(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), FakeAuthRepository.demoEmail);
  await tester.enterText(find.byType(TextFormField).at(1), FakeAuthRepository.demoPassword);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}
