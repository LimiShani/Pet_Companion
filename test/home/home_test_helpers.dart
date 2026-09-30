import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/home/home_screen.dart';
import 'package:pet_companion/features/home/widgets/home_header.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';
import 'package:pet_companion/theme/app_theme.dart';

import '../helpers.dart';

const kellyId = 'kelly';
const soyaId = 'soya';

/// The first number the emergency sheet offers for the sample Kelly.
const kellyVetPhone = '+972 3 555 0142';

final emergencyPill = find.byType(EmergencyButton);
final emergencyDot = find.byKey(const Key('emergency-dot'));
final topBar = find.byType(HomeTopBar);

class _FixedPets extends PetsNotifier {
  _FixedPets(this._pets);

  final List<Pet> _pets;

  @override
  List<Pet> build() => _pets;
}

void _setScreen(WidgetTester tester, Size size, double statusBar) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = FakeViewPadding(top: statusBar * 3);
  addTearDown(tester.view.reset);
}

/// Pumps the whole app on its fakes at [size], signs in as the demo user
/// and lands on the Home dashboard. Health's in-memory sample data is used
/// as it is (Kelly has vets, Soya has none). Returns the launcher that
/// records what the emergency sheet asks the phone to open.
Future<RecordingContactLauncher> pumpHome(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double statusBar = 0,
  List<Pet>? pets,
}) async {
  // Sign in on a regular phone (the login form needs its height), then
  // switch to the screen under test.
  _setScreen(tester, const Size(390, 844), 0);
  final launcher = RecordingContactLauncher();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        contactLauncherProvider.overrideWithValue(launcher),
        if (pets != null) petsProvider.overrideWith(() => _FixedPets(pets)),
      ],
      child: const PetCompanionApp(),
    ),
  );
  await tester.pumpAndSettle();
  await signInAsDemo(tester);
  _setScreen(tester, size, statusBar);
  await settle(tester);
  return launcher;
}

/// Pumps the top bar alone, in the app's theme, at [width].
Future<void> pumpTopBar(
  WidgetTester tester, {
  required double width,
  String petId = kellyId,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) async {
  _setScreen(tester, Size(width, 600), 0);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope every time, so one test can pump several widths.
      key: UniqueKey(),
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero))],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(alignment: Alignment.topCenter, child: HomeTopBar(petId: petId)),
          ),
        ),
      ),
    ),
  );
  await settle(tester);
}

/// Lets Health's sample data finish loading (its in-memory store answers
/// after a short delay), then lets every animation finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
}

/// Scrolls the dashboard as far down as it goes and returns how far that was.
Future<double> scrollHomeToBottom(WidgetTester tester) async {
  final scrollable = find.descendant(of: find.byKey(HomeScreen.scrollKey), matching: find.byType(Scrollable)).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  await tester.drag(find.byKey(HomeScreen.scrollKey), Offset(0, -(position.maxScrollExtent + 200)));
  await settle(tester);
  expect(position.pixels, position.maxScrollExtent);
  return position.pixels;
}

/// The pet the Emergency pill on screen acts for.
String pillPetId(WidgetTester tester) => tester.widget<EmergencyButton>(emergencyPill).petId;
