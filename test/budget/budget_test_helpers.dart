import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/budget/budget.dart';
import 'package:pet_companion/features/care/data/care_repository.dart';
import 'package:pet_companion/features/care/state/care_providers.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/features/store/data/fake_store_repository.dart';
import 'package:pet_companion/features/store/state/store_providers.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notification_sink.dart';

import '../helpers.dart';

/// The sample day in the afternoon: Kelly's 12 kg of food, bought on 2 May
/// and eaten at 280 g a day, runs out on 13 June.
final sampleAfternoon = DateTime(2025, 6, 10, 15);

/// Records what the basket asks the phone to schedule.
class RecordingSink implements NotificationSink {
  final groups = <String, List<PlannedNotification>>{};

  @override
  Future<void> syncGroup(String group, List<PlannedNotification> items) async => groups[group] = items;
}

/// Pumps the whole app at phone size on zero-latency fakes, with the
/// health, care, store and budget data living on [now], signs in as the
/// demo user and lands on Home.
Future<void> pumpBudgetApp(
  WidgetTester tester, {
  DateTime? now,
  AppLanguage? language,
  FakeBudgetRepository? budget,
  NotificationSink sink = const NoopNotificationSink(),
}) async {
  final at = now ?? sampleAfternoon;
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        settingsStoreProvider.overrideWithValue(MemorySettingsStore({languageSettingKey: ?language?.code})),
        healthClockProvider.overrideWithValue(() => at),
        healthRepositoryProvider.overrideWithValue(FakeHealthRepository(latency: Duration.zero, now: () => at)),
        careRepositoryProvider.overrideWithValue(FakeCareRepository(latency: Duration.zero)),
        storeClockProvider.overrideWithValue(() => at),
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository(latency: Duration.zero, now: () => at)),
        budgetRepositoryProvider.overrideWithValue(
          budget ?? FakeBudgetRepository(latency: Duration.zero, now: () => at),
        ),
        notificationSinkProvider.overrideWithValue(sink),
      ],
      child: const PetLoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  await signInAsDemo(tester);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Scrolls the page's list (down, or [up]) until [finder] is built and on
/// screen.
Future<void> scrollTo(WidgetTester tester, Finder finder, {bool up = false}) async {
  final vertical = find.byWidgetPredicate(
    (widget) => widget is Scrollable && axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
  );
  await tester.scrollUntilVisible(finder, up ? -150 : 150, scrollable: vertical.last);
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into the middle of the screen (not under Home's
/// pinned bar), taps it and waits.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) await scrollTo(tester, finder);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await settle(tester);
}

/// Opens the budget page from the side menu.
Future<void> openBudgetFromMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip(lookupAppL10n(const Locale('en')).homeMenu));
  await settle(tester);
  await tester.tap(find.byKey(const Key('side-menu-budget')));
  await settle(tester);
  expect(find.byKey(BudgetScreen.screenKey), findsOneWidget);
}

/// Opens the Store tab on "My basket".
Future<void> openBasket(WidgetTester tester, {String store = 'Store', String basket = 'My basket'}) async {
  await tester.tap(find.text(store).last);
  await settle(tester);
  await tester.tap(find.text(basket));
  await settle(tester);
  expect(find.byKey(BasketView.viewKey), findsOneWidget);
}
