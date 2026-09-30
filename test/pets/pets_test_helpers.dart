import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/features/pets/data/fake_pets_repository.dart';
import 'package:pet_companion/features/pets/data/pets_repository.dart';
import 'package:pet_companion/features/pets/data/pets_repository_provider.dart';
import 'package:pet_companion/features/pets/data/photo_services.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';
import 'package:pet_companion/theme/app_theme.dart';

/// The Pets strings in English and in Hebrew, for tests that name a text.
final en = lookupPetsL10n(englishLocale);
final he = lookupPetsL10n(hebrewLocale);

/// The instant every Pets test runs at: the Health sample data's day.
final petsNow = DateTime(2025, 6, 10, 17, 40);

const kelly = 'kelly';
const soya = 'soya';

/// A small real picture (PNG), standing in for a photo from the camera.
final Uint8List testPhoto = img.encodePng(img.Image(width: 8, height: 6));

/// Hands out a prepared photo instead of opening the camera or the photo
/// library.
class FakePetPhotoPicker implements PetPhotoPicker {
  Uint8List? photo = testPhoto;

  /// When set, picking fails with this message.
  String? failure;
  final asked = <PetPhotoSource>[];

  @override
  Future<Uint8List?> pick(PetPhotoSource source) async {
    asked.add(source);
    final message = failure;
    if (message != null) throw PetsException(message);
    return photo;
  }
}

/// Answers the crop step at once: with the photo as it is, or with the
/// prepared [outcomes] in turn.
class FakePetPhotoCropper implements PetPhotoCropper {
  final outcomes = <CropOutcome>[];
  int calls = 0;

  @override
  Future<CropOutcome> crop(BuildContext context, Uint8List photo) async {
    calls++;
    return outcomes.isEmpty ? CropOutcome.cropped(photo) : outcomes.removeAt(0);
  }
}

/// Everything a Pets test can swap out. All fakes answer at once.
class PetsHarness {
  PetsHarness({
    FakePetsRepository? pets,
    FakeHealthRepository? health,
    List<Override> extra = const [],
    this.language = AppLanguage.english,
  })  : pets = pets ?? FakePetsRepository(latency: Duration.zero),
        health = health ?? FakeHealthRepository(latency: Duration.zero, now: () => petsNow),
        _extra = extra;

  final FakePetsRepository pets;
  final FakeHealthRepository health;
  final FakeAuthRepository auth = FakeAuthRepository(latency: Duration.zero);
  final FakePetPhotoPicker picker = FakePetPhotoPicker();
  final FakePetPhotoCropper cropper = FakePetPhotoCropper();
  final List<Override> _extra;

  /// The language the app (or the host page) is shown in.
  final AppLanguage language;

  bool get isHebrew => language == AppLanguage.hebrew;

  DateTime now = petsNow;

  List<Override> overrides() => [
        authRepositoryProvider.overrideWithValue(auth),
        petsRepositoryProvider.overrideWithValue(pets),
        petsClockProvider.overrideWithValue(() => now),
        petPhotoPickerProvider.overrideWithValue(picker),
        petPhotoCropperProvider.overrideWithValue(cropper),
        healthClockProvider.overrideWithValue(() => now),
        healthRepositoryProvider.overrideWithValue(health),
        settingsStoreProvider.overrideWithValue(MemorySettingsStore({languageSettingKey: ?language.code})),
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
        locale: h.isHebrew ? hebrewLocale : englishLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
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

/// The pets the tabs see right now.
List<Pet> currentPets(WidgetTester tester) => appContainer(tester).read(petsProvider);

/// The pet with [name] among the visible pets.
Pet petNamed(WidgetTester tester, String name) => currentPets(tester).firstWhere((p) => p.name == name);

/// Scrolls [finder] into view and types [text] into it.
Future<void> typeInto(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view and taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens the flow from the first-pet welcome of a new account.
Future<PetsHarness> openFlowFromWelcome(WidgetTester tester, {PetsHarness? harness}) async {
  final h = await pumpPetsApp(tester, harness: harness, as: SignedIn.newAccount);
  await tapVisible(tester, find.text('Add my first pet'));
  return h;
}

/// Fills step 1 and continues.
Future<void> createPet(WidgetTester tester, {String name = 'Milo', PetSpecies? kind}) async {
  await typeInto(tester, find.byKey(const Key('pet-name')), name);
  if (kind != null) await tapVisible(tester, find.byKey(Key('kind-${kind.name}')));
  await tapVisible(tester, find.text('Continue'));
}
