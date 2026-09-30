import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/community_providers.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/data/photo_picker.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import '../helpers.dart';

/// The seeded demo account the tests sign in with.
const demoUser = AppUser(id: 'demo', email: FakeAuthRepository.demoEmail, displayName: 'Alex');

/// The fixed "now" of the community tests.
final testNow = DateTime(2026, 5, 14, 9, 41);
DateTime testClock() => testNow;

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

/// The fakes behind a pumped Community tab.
class CommunityHarness {
  CommunityHarness({FakeFeedRepository? feed, FakeChatRepository? chat})
      : feed = feed ?? FakeFeedRepository(latency: Duration.zero, now: testClock),
        chat = chat ?? FakeChatRepository(latency: Duration.zero, now: testClock);

  final FakeFeedRepository feed;
  final FakeChatRepository chat;
  final picker = FakePhotoPicker();
}

/// Pumps the whole app at phone size on zero-latency fakes, signs in with
/// the demo account (Alex, id `demo`) and opens the Community tab.
Future<CommunityHarness> pumpCommunity(WidgetTester tester, {CommunityHarness? harness}) async {
  final h = harness ?? CommunityHarness();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        communityClockProvider.overrideWithValue(testClock),
        feedRepositoryProvider.overrideWithValue(h.feed),
        chatRepositoryProvider.overrideWithValue(h.chat),
        photoPickerProvider.overrideWithValue(h.picker),
      ],
      child: const PetCompanionApp(),
    ),
  );
  await tester.pumpAndSettle();
  await signInAsDemo(tester);

  await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text('Community')));
  await tester.pumpAndSettle();
  return h;
}

/// Switches the section with the header's segmented control.
Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The feed as the demo account would fetch it now. The fake answers on a
/// timer, which only runs outside the test's fake clock.
Future<List<Post>> storedPosts(WidgetTester tester, CommunityHarness h) async {
  final posts = await tester.runAsync(() => h.feed.fetchPosts(viewer: demoUser));
  return posts!;
}
