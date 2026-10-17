import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/settings/settings_pages.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';
import 'package:pet_companion/notifications/widgets/notification_settings_card.dart';
import 'package:pet_companion/theme/app_theme.dart';

import '../helpers.dart';
import '../notifications/notification_test_helpers.dart';

final _en = lookupNotificationsL10n(englishLocale);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }
}

Future<ProviderContainer> _pumpSettings(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.english,
  required SettingsStore store,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: language == AppLanguage.hebrew ? hebrewLocale : englishLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: const NotificationSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _container(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('after sign-in each pet has its week waiting on the phone, on '
      'the first day of the week at 9:00', (tester) async {
    final phone = FakeNotificationPlatform();
    await pumpAppWithNotifications(tester, phone);
    await signInAsDemo(tester);
    await _settle(tester);

    final kelly = phone.of('week:kelly');
    expect(kelly, hasLength(1));
    final week = kelly.single;
    expect(week.kind, NotificationKind.weekly);
    expect(week.title, "Kelly's week");
    expect(week.body, isNotEmpty);
    expect(week.at.weekday, DateTime.sunday);
    expect((week.at.hour, week.at.minute), (9, 0));
    expect(week.at.isAfter(DateTime.now()), isTrue);
    expect(week.done, isNull);
    expect(phone.channelNames[NotificationKind.weekly], _en.weekly);

    // Off in Settings: off the phone at once.
    await _container(tester).read(notificationSettingsProvider.notifier).setKind(NotificationKind.weekly, false);
    await _settle(tester);
    expect(phone.of('week:kelly'), isEmpty);
    expect(phone.of('health:kelly'), isNotEmpty, reason: 'the other reminders stay');

    // Back on, on Wednesday at 20:15.
    final settings = _container(tester).read(notificationSettingsProvider.notifier);
    await settings.setKind(NotificationKind.weekly, true);
    await settings.setWeeklyTime(day: DateTime.wednesday, minutes: 20 * 60 + 15);
    await _settle(tester);
    final moved = phone.of('week:kelly').single.at;
    expect(moved.weekday, DateTime.wednesday);
    expect((moved.hour, moved.minute), (20, 15));
  });

  testWidgets('Settings > Notifications: the weekly summary, its day and its '
      'time', (tester) async {
    final store = MemorySettingsStore();
    final container = await _pumpSettings(tester, store: store);
    final weekly = find.byKey(NotificationSettingsCard.kindKey(NotificationKind.weekly));
    expect(tester.widget<SwitchListTile>(weekly).value, isTrue);
    expect(find.text(_en.weekly), findsOneWidget);
    expect(find.text(_en.weeklyNote), findsOneWidget);
    final day = find.byKey(NotificationSettingsCard.weeklyDayKey);
    expect(find.descendant(of: day, matching: find.text('Sunday')), findsOneWidget);

    await _tap(tester, day);
    // In the order of the week: Sunday first.
    final first = tester.getTopLeft(find.byKey(const ValueKey('notifications-weekly-day-7')));
    final monday = tester.getTopLeft(find.byKey(const ValueKey('notifications-weekly-day-1')));
    expect(first.dy, lessThan(monday.dy));
    await _tap(tester, find.byKey(const ValueKey('notifications-weekly-day-3')));
    expect(store.values[weeklyDaySettingKey], '3');
    expect(find.descendant(of: day, matching: find.text('Wednesday')), findsOneWidget);

    final time = find.byKey(NotificationSettingsCard.weeklyTimeKey);
    expect(find.descendant(of: time, matching: find.text('09:00')), findsOneWidget);
    await _tap(tester, time);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(store.values[weeklyTimeSettingKey], '09:00');

    // Off: the day and time rows go.
    await _tap(tester, weekly);
    expect(container.read(notificationSettingsProvider).weekly, isFalse);
    expect(day, findsNothing);
    expect(time, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final language in [AppLanguage.english, AppLanguage.hebrew]) {
    testWidgets('the weekly rows fit at 320 px (${language.name})', (tester) async {
      await _pumpSettings(tester, store: MemorySettingsStore(), language: language, size: const Size(320, 568));
      for (final key in [
        NotificationSettingsCard.kindKey(NotificationKind.weekly),
        NotificationSettingsCard.weeklyDayKey,
        NotificationSettingsCard.weeklyTimeKey,
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        final box = tester.getRect(find.byKey(key));
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(320));
        expect(box.height, greaterThanOrEqualTo(44));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
