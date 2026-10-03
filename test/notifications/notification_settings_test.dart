import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/settings/settings_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';
import 'package:pet_companion/notifications/widgets/notification_settings_card.dart';
import 'package:pet_companion/theme/app_theme.dart';

import '../helpers.dart';
import 'notification_test_helpers.dart';

// Settings > Notifications: the switches, quiet hours, and what the phone
// allows, in English and Hebrew.

/// The Settings page on its own, with [platform] as the phone (none when
/// `null`, as in the other tests of the app).
Future<ProviderContainer> _pumpSettings(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.english,
  SettingsStore? store,
  FakeNotificationPlatform? platform,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final scope = ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(store ?? MemorySettingsStore()),
      if (platform != null) notificationPlatformProvider.overrideWithValue(platform),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: language == AppLanguage.hebrew ? hebrewLocale : englishLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: const SettingsScreen(),
    ),
  );
  await tester.pumpWidget(scope);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
}

bool _on(WidgetTester tester, Key key) => tester.widget<SwitchListTile>(find.byKey(key)).value;
bool _enabled(WidgetTester tester, Key key) => tester.widget<SwitchListTile>(find.byKey(key)).onChanged != null;

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

  testWidgetsInBothLanguages('the section lists every switch, all on and quiet hours off', (tester, language) async {
    final l10n = lookupNotificationsL10n(language == AppLanguage.hebrew ? hebrewLocale : englishLocale);
    await _pumpSettings(tester, language: language);

    expect(find.text(l10n.sectionTitle), findsOneWidget);
    for (final text in [
      l10n.masterTitle,
      l10n.meals,
      l10n.walks,
      l10n.medicines,
      l10n.appointments,
      l10n.appointmentsNote,
      l10n.basket,
      l10n.basketNote,
      l10n.quietHours,
      l10n.quietHoursNote,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(_on(tester, NotificationSettingsCard.masterKey), isTrue);
    for (final kind in NotificationKind.values) {
      expect(_on(tester, NotificationSettingsCard.kindKey(kind)), isTrue);
    }
    expect(_on(tester, NotificationSettingsCard.quietHoursKey), isFalse);
    // No phone (tests, the web): nothing about permissions.
    expect(find.byKey(NotificationSettingsCard.exactKey), findsNothing);
    expect(find.byKey(NotificationSettingsCard.blockedKey), findsNothing);
  });

  testWidgets('a switch applies at once and is remembered on the phone', (tester) async {
    final store = MemorySettingsStore();
    final container = await _pumpSettings(tester, store: store);

    await _tap(tester, find.byKey(NotificationSettingsCard.kindKey(NotificationKind.walk)));
    await _tap(tester, find.byKey(NotificationSettingsCard.quietHoursKey));
    expect(_on(tester, NotificationSettingsCard.kindKey(NotificationKind.walk)), isFalse);
    expect(_on(tester, NotificationSettingsCard.quietHoursKey), isTrue);
    expect(container.read(notificationSettingsProvider), const NotificationSettings(walks: false, quietHours: true));
    expect(store.values[notificationKindSettingKey(NotificationKind.walk)], '0');
    expect(store.values[quietHoursSettingKey], '1');

    // The master switch turns everything off; the others wait, greyed.
    await _tap(tester, find.byKey(NotificationSettingsCard.masterKey));
    expect(container.read(notificationSettingsProvider).enabled, isFalse);
    expect(_enabled(tester, NotificationSettingsCard.kindKey(NotificationKind.meal)), isFalse);
    expect(_enabled(tester, NotificationSettingsCard.quietHoursKey), isFalse);
  });

  testWidgets('the choices are read back after a restart', (tester) async {
    final store = MemorySettingsStore({
      notificationKindSettingKey(NotificationKind.basket): '0',
      quietHoursSettingKey: '1',
    });
    await _pumpSettings(tester, store: store);
    expect(_on(tester, NotificationSettingsCard.kindKey(NotificationKind.basket)), isFalse);
    expect(_on(tester, NotificationSettingsCard.kindKey(NotificationKind.meal)), isTrue);
    expect(_on(tester, NotificationSettingsCard.quietHoursKey), isTrue);
  });

  testWidgets('without "Alarms & reminders" the row explains and offers it', (tester) async {
    final l10n = lookupNotificationsL10n(englishLocale);
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: false));
    await _pumpSettings(tester, platform: phone);

    expect(find.text(l10n.exactTitle), findsOneWidget);
    expect(find.text(l10n.exactNote), findsOneWidget);
    expect(find.text(l10n.exactMissing), findsOneWidget);
    await _tap(tester, find.byKey(NotificationSettingsCard.exactAllowKey));
    expect(phone.exactRequests, 1);
    // Granted: the row says so, and the button is gone.
    expect(find.text(l10n.exactAllowed), findsOneWidget);
    expect(find.byKey(NotificationSettingsCard.exactAllowKey), findsNothing);
    expect(find.byKey(NotificationSettingsCard.blockedKey), findsNothing);
  });

  testWidgets('when the phone blocks notifications, a button opens its settings', (tester) async {
    final l10n = lookupNotificationsL10n(hebrewLocale);
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: false, exact: true));
    await _pumpSettings(tester, language: AppLanguage.hebrew, platform: phone);

    expect(find.text(l10n.blockedTitle), findsOneWidget);
    expect(find.text(l10n.exactAllowed), findsOneWidget);
    await _tap(tester, find.byKey(NotificationSettingsCard.openSettingsKey));
    expect(phone.settingsOpened, 1);
    // Never the system prompt from here: the owner already answered it.
    expect(phone.permissionRequests, 0);
  });

  testWidgets('on iPhone there is no "Exact time" row', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true));
    await _pumpSettings(tester, platform: phone);
    expect(find.byKey(NotificationSettingsCard.exactKey), findsNothing);
    expect(find.byKey(NotificationSettingsCard.blockedKey), findsNothing);
  });

  testWidgets('the section fits a small phone with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: false, exact: false));
    await _pumpSettings(tester, platform: phone);
    tester.view.physicalSize = const Size(320, 568) * 3;
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(NotificationSettingsCard.exactAllowKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
