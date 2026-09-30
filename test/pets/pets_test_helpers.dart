import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/features/pets/data/fake_pets_repository.dart';
import 'package:pet_companion/features/pets/data/pets_repository_provider.dart';
import 'package:pet_companion/theme/app_theme.dart';

/// The instant every Pets test runs at: the Health sample data's day.
final petsNow = DateTime(2025, 6, 10, 17, 40);

const kelly = 'kelly';
const soya = 'soya';

/// Everything a Pets test can swap out. All fakes answer at once.
class PetsHarness {
  PetsHarness({FakePetsRepository? pets, FakeHealthRepository? health, List<Override> extra = const []})
      : pets = pets ?? FakePetsRepository(latency: Duration.zero),
        health = health ?? FakeHealthRepository(latency: Duration.zero, now: () => petsNow),
        _extra = extra;

  final FakePetsRepository pets;
  final FakeHealthRepository health;
  final FakeAuthRepository auth = FakeAuthRepository(latency: Duration.zero);
  final List<Override> _extra;

  DateTime now = petsNow;

  List<Override> overrides() => [
        authRepositoryProvider.overrideWithValue(auth),
        petsRepositoryProvider.overrideWithValue(pets),
        petsClockProvider.overrideWithValue(() => now),
        healthClockProvider.overrideWithValue(() => now),
        healthRepositoryProvider.overrideWithValue(health),
        ..._extra,
      ];

  /// A container on the fakes, for tests without widgets.
  ProviderContainer container() {
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    return container;
  }
}

/// Who is signed in when a test starts.
enum SignedIn {
  /// The seeded demo account (Alex), which owns Kelly and Soya.
  demo,

  /// A brand-new account (Limor) without any pet.
  newAccount,

  /// Nobody: the login screen.
  nobody,
}

void _phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pumps the whole app on fakes at phone size and signs in.
Future<PetsHarness> pumpPetsApp(
  WidgetTester tester, {
  PetsHarness? harness,
  SignedIn as = SignedIn.demo,
  Size size = const Size(390, 844),
}) async {
  _phone(tester, size);
  final h = harness ?? PetsHarness();
  await tester.pumpWidget(ProviderScope(overrides: h.overrides(), child: const PetCompanionApp()));
  await tester.pumpAndSettle();
  await signIn(tester, as);
  return h;
}

/// Pumps [child] alone (in the app's theme, at phone size) on the fakes,
/// signed in. For pieces other tabs place, such as the reminder card.
Future<PetsHarness> pumpPetsHost(
  WidgetTester tester,
  Widget child, {
  PetsHarness? harness,
  SignedIn as = SignedIn.demo,
  Size size = const Size(390, 844),
}) async {
  _phone(tester, size);
  final h = harness ?? PetsHarness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: SafeArea(child: SingleChildScrollView(child: child))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await signIn(tester, as);
  return h;
}

/// Signs in through the auth controller (not the login form).
Future<void> signIn(WidgetTester tester, SignedIn as) async {
  if (as == SignedIn.nobody) return;
  final auth = appContainer(tester).read(authControllerProvider.notifier);
  // Not awaited: the fake's delays only elapse while the tester pumps.
  unawaited(as == SignedIn.demo
      ? auth.signIn(email: FakeAuthRepository.demoEmail, password: FakeAuthRepository.demoPassword)
      : auth.signUp(displayName: 'Limor', email: 'limor@example.com', password: 'walkies123'));
  await tester.pumpAndSettle();
}

/// The provider container of the widget tree under test.
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)), listen: false);

/// Scrolls [finder] into view and taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
