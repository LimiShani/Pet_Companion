import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';
import 'package:pet_companion/notifications/widgets/permission_sheet.dart';
import 'package:pet_companion/theme/app_theme.dart';

import 'notification_test_helpers.dart';

// The sheet that explains the reminders before the phone's own prompt.

Future<void> _pumpSheet(
  WidgetTester tester,
  FakeNotificationPlatform phone, {
  Locale locale = englishLocale,
  bool allowed = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showNotificationPermissionSheet(context, platform: phone, notificationsAllowed: allowed),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final _sheet = find.byKey(NotificationPermissionSheet.sheetKey);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('in Hebrew it explains what rings, then asks', (tester) async {
    final he = lookupNotificationsL10n(hebrewLocale);
    final phone = FakeNotificationPlatform(grantNotifications: false);
    await _pumpSheet(tester, phone, locale: hebrewLocale);

    for (final text in [he.askTitle, he.askIntro, he.askMeals, he.askMedicines, he.askAppointments, he.askAllow]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // Refused at the phone's prompt: the sheet just closes, nothing more.
    await tester.tap(find.byKey(NotificationPermissionSheet.allowKey));
    await tester.pumpAndSettle();
    expect(phone.permissionRequests, 1);
    expect(_sheet, findsNothing);
    expect(phone.exactRequests, 0);
  });

  testWidgets('allowed, with exact times already allowed: no second step', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: false, exact: true));
    await _pumpSheet(tester, phone);
    await tester.tap(find.byKey(NotificationPermissionSheet.allowKey));
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
  });

  testWidgets('notifications already allowed: it starts at "Alarms & reminders"', (tester) async {
    final en = lookupNotificationsL10n(englishLocale);
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: false));
    await _pumpSheet(tester, phone, allowed: true);
    expect(find.text(en.askExactTitle), findsOneWidget);
    expect(find.text(en.exactNote), findsOneWidget);

    await tester.tap(find.byKey(NotificationPermissionSheet.laterKey));
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(phone.exactRequests, 0);
  });

  testWidgets('fits a small phone with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpSheet(tester, FakeNotificationPlatform(), locale: hebrewLocale, size: const Size(320, 568));
    expect(_sheet, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
