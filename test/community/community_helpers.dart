import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/community/community_routes.dart';
import 'package:pet_companion/features/community/data/community_language.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/community_providers.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';
import 'package:pet_companion/features/community/data/photo_picker.dart';
import 'package:pet_companion/features/community/guides/guide_reader_screen.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';
import 'package:pet_companion/theme/app_theme.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import '../helpers.dart';

/// The seeded demo account the tests sign in with.
const demoUser = AppUser(id: 'demo', email: FakeAuthRepository.demoEmail, displayName: 'Alex');

/// The fixed "now" of the community tests.
final testNow = DateTime(2026, 5, 14, 9, 41);
DateTime testClock() => testNow;

/// A cat for the tests that need one: the sample data has two dogs.
const mitzi = Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat);
const kelly = Pet(id: 'kelly', name: 'Kelly');

/// A cat owner's pets: the cat first, so it is the selected pet.
const catFirst = [mitzi, kelly];

/// A valid 1x1 PNG, so `Image.memory` has something real to decode.
final onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Stands in for the platform photo picker.
class FakePhotoPicker implements PhotoPicker {
  final requests = <PhotoSource>[];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    requests.add(source);
    return PickedPhoto(bytes: onePixelPng, name: 'kelly.png', mimeType: 'image/png');
  }
}

/// Replaces the owner's pets for a test.
class FixedPets extends PetsNotifier {
  FixedPets(this._pets);

  final List<Pet> _pets;

  @override
  List<Pet> build() => _pets;
}

/// The fakes behind a pumped Community tab.
class CommunityHarness {
  CommunityHarness({
    FakeFeedRepository? feed,
    FakeChatRepository? chat,
    this.pets,
    this.guides,
    this.language = ContentLanguage.en,
  })  : feed = feed ?? FakeFeedRepository(latency: Duration.zero, now: testClock),
        chat = chat ?? FakeChatRepository(latency: Duration.zero, now: testClock);

  final FakeFeedRepository feed;
  final FakeChatRepository chat;
  final picker = FakePhotoPicker();

  /// Replaces the sample pets (two dogs); the first one is selected.
  final List<Pet>? pets;

  /// Replaces the bundled guides (to test a reviewed or translated guide).
  final GuidesRepository? guides;

  /// The language the content is asked for in.
  final ContentLanguage language;

  /// Every source link the reader asked the phone to open.
  final openedSources = <Uri>[];

  List<Override> get _overrides => [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        communityClockProvider.overrideWithValue(testClock),
        feedRepositoryProvider.overrideWithValue(feed),
        chatRepositoryProvider.overrideWithValue(chat),
        photoPickerProvider.overrideWithValue(picker),
        communityLanguageProvider.overrideWithValue(language),
        guideSourceOpenerProvider.overrideWithValue((uri) async {
          openedSources.add(uri);
          return true;
        }),
        if (guides != null) guidesRepositoryProvider.overrideWithValue(guides!),
        if (pets != null) petsProvider.overrideWith(() => FixedPets(pets!)),
      ];
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pumps the whole app at phone size on zero-latency fakes, signs in with
/// the demo account (Alex, id `demo`) and opens the Community tab.
Future<CommunityHarness> pumpCommunity(WidgetTester tester, {CommunityHarness? harness}) async {
  final h = harness ?? CommunityHarness();
  _setScreen(tester, const Size(390, 844));

  await tester.pumpWidget(
    ProviderScope(
      overrides: h._overrides,
      child: const PetCompanionApp(),
    ),
  );
  await tester.pumpAndSettle();
  await signInAsDemo(tester);

  await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text('Community')));
  await tester.pumpAndSettle();
  return h;
}

/// Pumps the Community tab alone (its own routes, the app's theme, no
/// bottom bar), signed in as the demo account, in [direction] and at
/// [size]. For what the whole app cannot be asked to do yet: a
/// right-to-left layout.
Future<CommunityHarness> pumpCommunityHost(
  WidgetTester tester, {
  CommunityHarness? harness,
  TextDirection direction = TextDirection.ltr,
  Size size = const Size(390, 844),
}) async {
  final h = harness ?? CommunityHarness();
  _setScreen(tester, size);

  final router = GoRouter(initialLocation: CommunityRoutes.root, routes: communityRoutes);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: h._overrides,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => Directionality(textDirection: direction, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Not awaited: the fake's delay only elapses while the tester pumps.
  unawaited(
    hostContainer(tester)
        .read(authControllerProvider.notifier)
        .signIn(email: FakeAuthRepository.demoEmail, password: FakeAuthRepository.demoPassword),
  );
  await tester.pumpAndSettle();
  return h;
}

/// The provider container of the widget tree under test.
ProviderContainer hostContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first), listen: false);

/// Switches the section with the header's segmented control.
Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Chooses Dogs, Cats or Everything in the section on screen.
Future<void> chooseScope(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('scope-$name')).hitTestable());
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the screen's main list until [finder] is in view. (The sections
/// also hold a horizontal row of chips, so the list has to be named.)
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// Goes back with the header's arrow.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back').hitTestable());
  await tester.pumpAndSettle();
}

/// Lets Health's sample data finish loading (its in-memory store answers
/// after a short delay), then lets every animation finish. Needed after
/// opening the emergency sheet.
Future<void> settleHealth(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Closes the bottom sheet on top.
Future<void> closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
  await tester.pumpAndSettle();
}

/// The feed as the demo account would fetch it now. The fake answers on a
/// timer, which only runs outside the test's fake clock.
Future<List<Post>> storedPosts(WidgetTester tester, CommunityHarness h) async {
  final posts = await tester.runAsync(() => h.feed.fetchPosts(viewer: demoUser));
  return posts!;
}
