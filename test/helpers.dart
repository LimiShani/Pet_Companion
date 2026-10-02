import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/primary_button.dart';

/// Pumps the whole app at phone size with a zero-latency fake auth backend.
/// Lands on the login screen.
///
/// The app starts in English, as every existing test expects. Pass
/// [language] to start it in Hebrew (right to left), or [settings] to hand
/// it a store of saved choices: giving the same [MemorySettingsStore] to
/// two calls simulates closing the app and opening it again. [size] and
/// [textScale] are for layout checks on a small phone or with large text.
Future<void> pumpApp(
  WidgetTester tester, {
  AppLanguage? language,
  SettingsStore? settings,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final store = settings ?? MemorySettingsStore({languageSettingKey: ?language?.code});
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope on every call, so one test can start the app twice.
      key: UniqueKey(),
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        settingsStoreProvider.overrideWithValue(store),
      ],
      child: const PetLoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Signs in with the seeded demo account from the login screen, in
/// whichever language the app is showing.
Future<void> signInAsDemo(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), FakeAuthRepository.demoEmail);
  await tester.enterText(find.byType(TextFormField).at(1), FakeAuthRepository.demoPassword);
  await tester.tap(find.byType(PrimaryButton));
  await tester.pumpAndSettle();
}

/// Runs [body] once for English and once for Hebrew, for checks that must
/// hold in both languages and directions.
void testWidgetsInBothLanguages(
  String description,
  Future<void> Function(WidgetTester tester, AppLanguage language) body,
) {
  for (final language in [AppLanguage.english, AppLanguage.hebrew]) {
    testWidgets('$description (${language.name})', (tester) => body(tester, language));
  }
}
