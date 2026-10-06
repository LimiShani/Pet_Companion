import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/access/access_admin_screen.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/auth/reset_password_screen.dart';
import 'package:pet_companion/navigation/app_router.dart';
import 'package:pet_companion/platform/feature_module.dart';
import '../helpers.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'recovery opens the password form and saves a usable new password',
    (tester) async {
      await pumpApp(tester, now: DateTime(2025, 6, 10));
      await signInAsDemo(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final repository =
          container.read(authRepositoryProvider) as FakeAuthRepository;
      repository.beginRecovery();
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'newpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'newpassword123',
      );
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsNothing);
      final signedIn = await tester.runAsync(
        () => repository.signIn(
          email: FakeAuthRepository.demoEmail,
          password: 'newpassword123',
        ),
      );
      expect(signedIn?.id, 'demo');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'administrator opens Feature access from Home and sees all management tabs',
    (tester) async {
      await pumpApp(tester, now: DateTime(2025, 6, 10));
      await signInAsDemo(tester);
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Feature access'));
      await tester.tap(find.text('Feature access'));
      await tester.pumpAndSettle();
      expect(find.byType(AccessAdministrationScreen), findsOneWidget);
      for (final label in ['Users', 'Groups', 'Features', 'Audit']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Features'));
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(SwitchListTile, 'Daily care');
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccessAdministrationScreen)),
      );
      expect(container.read(capabilityProvider('care.view')), isFalse);
      await tester.tap(find.text('Audit'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Feature settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new regular owner sees no permission administration and denied modules disappear',
    (tester) async {
      final access = FakeAccessRepository();
      access.features['health'] = false;
      access.features['community'] = false;
      await pumpApp(
        tester,
        now: DateTime(2025, 6, 10),
        overrides: [accessRepositoryProvider.overrideWithValue(access)],
      );
      await signInAsDemo(tester);
      expect(find.text('Health'), findsNothing);
      expect(find.text('Community'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(authControllerProvider.notifier)
          .signUp(
            displayName: 'Owner',
            email: 'owner@example.test',
            password: 'owner1234',
          );
      await tester.pumpAndSettle();
      expect(container.read(capabilityProvider('access.admin')), isFalse);
      expect(container.read(capabilityProvider('findvet.admin')), isFalse);
      expect(find.text('Feature access'), findsNothing);
      expect(find.byType(AccessAdministrationScreen), findsNothing);
    },
  );

  testWidgets('shell operates when every optional UI module is removed', (
    tester,
  ) async {
    await pumpApp(
      tester,
      now: DateTime(2025, 6, 10),
      overrides: [
        featureModulesProvider.overrideWithValue(const []),
        installedFeaturesProvider.overrideWithValue({'access'}),
      ],
    );
    await signInAsDemo(tester);
    expect(find.text('Health'), findsNothing);
    expect(find.text('Community'), findsNothing);
    expect(find.text('Store'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      AppRoutes.home,
    );
    expect(tester.takeException(), isNull);
  });
}
