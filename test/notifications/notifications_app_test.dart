import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/features/care/care.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/health_screen.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';
import 'package:pet_companion/notifications/widgets/permission_sheet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import '../helpers.dart';
import 'notification_test_helpers.dart';

// The whole app with real reminders on a fake phone: every pet rings after
// sign-in, the permission is asked once with an explanation first, a tapped
// reminder opens its page, and signing out silences the phone.

final _en = lookupNotificationsL10n(englishLocale);

final _sheet = find.byKey(NotificationPermissionSheet.sheetKey);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

/// Lets the reminders of every pet load and reach the phone.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }
}

Future<void> _signIn(WidgetTester tester) async {
  await signInAsDemo(tester);
  await _settle(tester);
}

/// Closes the permission sheet with "Not now".
Future<void> _notNow(WidgetTester tester) async {
  await tester.tap(find.byKey(NotificationPermissionSheet.laterKey));
  await _settle(tester);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('after sign-in every pet\'s reminders wait on the phone', (tester) async {
    final phone = FakeNotificationPlatform();
    final health = FakeHealthRepository(latency: Duration.zero, now: () => DateTime(2025, 6, 10, 12));
    // Soya has no routine in the sample data: give her a walk.
    await tester.runAsync(
      () => health.savePlanItem(
        const CarePlanItem(
          id: '',
          petId: 'soya',
          kind: CareKind.walk,
          title: 'Garden time',
          time: TimeOfDay(hour: 17, minute: 0),
        ),
      ),
    );
    await pumpAppWithNotifications(tester, phone, health: health);
    expect(phone.scheduled, isEmpty);
    await _signIn(tester);
    await _notNow(tester);

    // Kelly's routines and medicine, and Soya's, without opening Health.
    final kelly = phone.of('health:kelly');
    expect(kelly, isNotEmpty);
    expect(phone.of('health:soya').map((n) => n.body).toSet(), {'Garden time'});
    expect(phone.of('health:soya').first.title, 'PetLoop · Soya');
    expect(kelly.map((n) => n.title).toSet(), {'PetLoop · Kelly'});
    final bodies = kelly.map((n) => n.body).toSet();
    expect(bodies, containsAll(['Dinner · time to feed', 'Joint tablets · 1 tablet', 'Evening walk']));
    // The sample check two days after the sample day rings the evening before.
    expect(bodies, contains('Tomorrow 18:20: General check · Park Vet Clinic'));
    expect(phone.channelNames[NotificationKind.medicine], _en.medicines);
  });

  testWidgets('the explanation comes first, then the phone\'s prompt, then "Alarms & reminders"', (tester) async {
    final store = MemorySettingsStore();
    final phone = FakeNotificationPlatform();
    await pumpAppWithNotifications(tester, phone, settings: store);
    // Not on the sign-in screen: only once the account has reminders.
    expect(_sheet, findsNothing);
    await _signIn(tester);

    expect(_sheet, findsOneWidget);
    expect(find.text(_en.askTitle), findsOneWidget);
    expect(find.text(_en.askMedicines), findsOneWidget);
    expect(phone.permissionRequests, 0);

    await tester.tap(find.byKey(NotificationPermissionSheet.allowKey));
    await _settle(tester);
    expect(phone.permissionRequests, 1);
    expect(find.text(_en.askExactTitle), findsOneWidget);

    await tester.tap(find.byKey(NotificationPermissionSheet.exactKey));
    await _settle(tester);
    expect(phone.exactRequests, 1);
    expect(_sheet, findsNothing);
    expect(store.values[notificationsAskedSettingKey], '1');
    // Now allowed to ring exactly, everything is exact.
    expect(phone.scheduled.values.every((n) => n.exact), isTrue);
  });

  testWidgets('asked once: not again after "Not now", not after a restart', (tester) async {
    final store = MemorySettingsStore();
    final phone = FakeNotificationPlatform(grantNotifications: false);
    await pumpAppWithNotifications(tester, phone, settings: store);
    await _signIn(tester);
    await _notNow(tester);
    expect(_sheet, findsNothing);
    expect(phone.permissionRequests, 0);

    await pumpAppWithNotifications(tester, phone, settings: store);
    await _signIn(tester);
    expect(_sheet, findsNothing);
  });

  testWidgets('no sheet when the phone already allows everything', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    await pumpAppWithNotifications(tester, phone);
    await _signIn(tester);
    expect(_sheet, findsNothing);
    expect(phone.scheduled, isNotEmpty);
  });

  testWidgets('a meal reminder opens the feeding page of its pet', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    await pumpAppWithNotifications(tester, phone);
    await _signIn(tester);
    expect(_container(tester).read(selectedPetIdProvider), 'kelly');

    phone.tap('feeding:soya');
    await _settle(tester);
    expect(find.byKey(FeedingScreen.screenKey), findsOneWidget);
    expect(_container(tester).read(selectedPetIdProvider), 'soya');
  });

  testWidgets('a walk reminder opens the activity page; a medicine one the Health schedule', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    await pumpAppWithNotifications(tester, phone);
    await _signIn(tester);

    phone.tap('activity:kelly');
    await _settle(tester);
    expect(find.byKey(ActivityScreen.screenKey), findsOneWidget);

    phone.tap('health:kelly');
    await _settle(tester);
    expect(find.byKey(ActivityScreen.screenKey), findsNothing);
    expect(find.byType(HealthScreen), findsOneWidget);
    expect(_container(tester).read(healthSectionProvider), HealthSection.schedule);
  });

  testWidgets('a reminder tapped before sign-in opens once the owner is in', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    // The tap that launched the app arrives before anything is on screen.
    phone.tap('feeding:kelly');
    await pumpAppWithNotifications(tester, phone);
    expect(find.byKey(FeedingScreen.screenKey), findsNothing);

    await _signIn(tester);
    expect(find.byKey(FeedingScreen.screenKey), findsOneWidget);
  });

  testWidgets('a meal logged early is not reminded of', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    await pumpAppWithNotifications(tester, phone);
    await _signIn(tester);
    final container = _container(tester);
    String today(String item) {
      final d = DateTime.now();
      return 'item:$item@${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    final sink = container.read(notificationSinkProvider) as LocalNotificationSink;
    Iterable<String> planned() => sink.groups['health:kelly']!.map((n) => n.key);
    // What Health planned for Kelly, before the sink drops what is past.
    expect(planned(), contains(today('p-dinner')));

    final plan = container.read(carePlanProvider('kelly')).requireValue;
    final dinner = plan.items.firstWhere((i) => i.id == 'p-dinner');
    final saving = container
        .read(carePlanProvider('kelly').notifier)
        .record(item: dinner, dueOn: container.read(healthClockProvider)(), status: CareLogStatus.done);
    await _settle(tester);
    await saving;
    expect(planned(), isNot(contains(today('p-dinner'))));
    expect(phone.of('health:kelly').where((n) => n.key == today('p-dinner')), isEmpty);
    expect(phone.of('health:kelly').where((n) => n.key.startsWith('item:p-dinner@')), isNotEmpty);
  });

  testWidgets('signing out cancels every reminder', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    await pumpAppWithNotifications(tester, phone);
    await _signIn(tester);
    expect(phone.scheduled, isNotEmpty);

    final signingOut = _container(tester).read(authControllerProvider.notifier).signOut();
    await _settle(tester);
    await signingOut;
    expect(phone.scheduled, isEmpty);
    expect(phone.log, contains('cancelAll'));
  });

  testWidgets('a session that ended while the app was closed silences its reminders', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    await pumpAppWithNotifications(tester, phone);
    await _signIn(tester);
    expect(phone.scheduled, isNotEmpty);

    // The app restarts signed out (password changed, or signed out on
    // another device): nobody signs in, the previous reminders must go.
    await pumpAppWithNotifications(tester, phone);
    await _settle(tester);
    expect(phone.scheduled, isEmpty);
  });

  testWidgets('the next account to sign in does not inherit "running low" reminders', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    // Left on the phone by another account's pet before the app started.
    final other = ScheduledNotification(
      group: 'basket:someone-elses-pet',
      key: 'low:food',
      kind: NotificationKind.basket,
      at: DateTime(2025, 6, 11, 9),
      title: 'PetLoop · Rex',
      body: 'Food is running low',
    );
    phone.scheduled[other.id] = other;

    await pumpAppWithNotifications(tester, phone);
    await _signIn(tester);

    expect(phone.of('basket:someone-elses-pet'), isEmpty);
    expect(phone.of('health:kelly'), isNotEmpty);
  });

  testWidgets('turning meals off in Settings takes them off the phone at once', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    await pumpAppWithNotifications(tester, phone);
    await _signIn(tester);
    expect(phone.scheduled.values.where((n) => n.kind == NotificationKind.meal), isNotEmpty);

    await _container(tester).read(notificationSettingsProvider.notifier).setKind(NotificationKind.meal, false);
    await _settle(tester);
    expect(phone.scheduled.values.where((n) => n.kind == NotificationKind.meal), isEmpty);
    expect(phone.scheduled.values.where((n) => n.kind == NotificationKind.medicine), isNotEmpty);
  });
}
