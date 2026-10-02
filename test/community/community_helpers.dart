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
import 'package:pet_companion/features/community/data/chat_repository.dart';
import 'package:pet_companion/features/community/data/community_language.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/community_providers.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';
import 'package:pet_companion/features/community/data/photo_picker.dart';
import 'package:pet_companion/features/community/guides/guide_reader_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';
import 'package:pet_companion/theme/app_theme.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import '../helpers.dart';

/// The Community's words in each language, as the strings files have them.
final en = lookupCommunityL10n(englishLocale);
final he = lookupCommunityL10n(hebrewLocale);
final appEn = lookupAppL10n(englishLocale);
final appHe = lookupAppL10n(hebrewLocale);

/// The English words the older tests name as constants.
final guideDisclaimer = en.guideDisclaimer;
final adviceNoticeText = en.adviceNotice;
final contactProfessionalLabel = en.contactProfessional;

/// A text as it reads: without the invisible direction marks.
String plain(String text) => stripBidiMarks(text);

/// A `Text` that reads [text], whatever direction marks it carries.
Finder reads(String text) => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          plain(widget.data ?? widget.textSpan?.toPlainText() ?? '') == plain(text),
      description: 'a text reading "$text"',
    );

/// The direction of the part of the screen [finder] is in.
TextDirection screenDirection(WidgetTester tester, Finder finder) => Directionality.of(tester.element(finder));

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
    this.language,
    this.appLanguage,
    this.chatBackend,
  })  : feed = feed ?? FakeFeedRepository(latency: Duration.zero, now: testClock),
        chat = chat ?? FakeChatRepository(latency: Duration.zero, now: testClock);

  final FakeFeedRepository feed;
  final FakeChatRepository chat;
  final picker = FakePhotoPicker();

  /// Replaces the sample pets (two dogs); the first one is selected.
  final List<Pet>? pets;

  /// Replaces the bundled guides (to test a reviewed or translated guide).
  final GuidesRepository? guides;

  /// Pins the language the guides are asked for in, whatever the app's
  /// language is. Left out, the guides follow the app's language, as they
  /// do in the app.
  final ContentLanguage? language;

  /// A chat backend of the test's own, used instead of [chat].
  final ChatRepository? chatBackend;

  /// The language the app starts in: English when left out.
  final AppLanguage? appLanguage;

  /// The saved choices of this app run (the language switch writes here).
  late final settings = MemorySettingsStore({languageSettingKey: ?appLanguage?.code});

  /// Every source link the reader asked the phone to open.
  final openedSources = <Uri>[];

  List<Override> get _overrides => [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        communityClockProvider.overrideWithValue(testClock),
        feedRepositoryProvider.overrideWithValue(feed),
        chatRepositoryProvider.overrideWithValue(chatBackend ?? chat),
        photoPickerProvider.overrideWithValue(picker),
        settingsStoreProvider.overrideWithValue(settings),
        if (language != null) communityLanguageProvider.overrideWithValue(language!),
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

/// Pumps the whole app at phone size ([size]) on zero-latency fakes, signs
/// in with the demo account (Alex, id `demo`) and opens the Community tab.
/// The app runs in the harness's language: English unless it says Hebrew.
Future<CommunityHarness> pumpCommunity(
  WidgetTester tester, {
  CommunityHarness? harness,
  Size size = const Size(390, 844),
}) async {
  final h = harness ?? CommunityHarness();
  // Signed in at the usual size; the screen under test then takes [size].
  _setScreen(tester, const Size(390, 844));

  await tester.pumpWidget(
    ProviderScope(
      overrides: h._overrides,
      child: const PetLoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  await signInAsDemo(tester);

  final tab = h.appLanguage == AppLanguage.hebrew ? appHe.navCommunity : appEn.navCommunity;
  await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text(tab)));
  await tester.pumpAndSettle();
  if (size != const Size(390, 844)) {
    tester.view.physicalSize = size * 3;
    await tester.pumpAndSettle();
  }
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

/// Goes back with the header's arrow, in whichever language is on screen.
Future<void> goBack(WidgetTester tester) async {
  final english = find.byTooltip(appEn.commonBack).hitTestable();
  await tester.tap(english.evaluate().isNotEmpty ? english : find.byTooltip(appHe.commonBack).hitTestable());
  await tester.pumpAndSettle();
}

/// Switches the app's language from inside the running app, as the
/// language switch in the menu does.
Future<void> switchLanguage(WidgetTester tester, AppLanguage language) async {
  // Not awaited: the store's write only completes while the tester pumps.
  unawaited(hostContainer(tester).read(appLanguageProvider.notifier).choose(language));
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
