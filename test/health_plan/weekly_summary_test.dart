import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';
import 'package:pet_companion/services/insights/weekly_summary.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/state/schedule_logic.dart';

final en = lookupNotificationsL10n(englishLocale);
final he = lookupNotificationsL10n(hebrewLocale);

/// Sunday 18 October 2026, the first day of an Israeli week.
final sunday = DateTime(2026, 10, 18);

const walkItem = CarePlanItem(
  id: 'walk',
  petId: 'kelly',
  kind: CareKind.walk,
  title: 'Evening walk',
  time: TimeOfDay(hour: 18, minute: 0),
);
const doseItem = CarePlanItem(
  id: 'dose',
  petId: 'kelly',
  kind: CareKind.medication,
  title: 'Joint tablets',
  time: TimeOfDay(hour: 8, minute: 0),
  medicationId: 'm',
);
const medicine = Medication(id: 'm', petId: 'kelly', name: 'Joint tablets');

CareLog log(CarePlanItem item, DateTime day, {CareLogStatus status = CareLogStatus.done}) => CareLog(
  id: '${item.id}@$day',
  petId: 'kelly',
  planItemId: item.id,
  medicationId: item.medicationId,
  title: item.title,
  dueOn: day,
  status: status,
  loggedAt: day,
);

/// Last week (11 to 17 October): every walk but two, every dose but one
/// (answered "not given"), and one dose nobody answered.
CarePlan lastWeek() {
  final from = DateTime(2026, 10, 11);
  return CarePlan(
    medications: const [medicine],
    items: const [walkItem, doseItem],
    logs: [
      for (var d = 0; d < 7; d++)
        if (d != 2 && d != 4) log(walkItem, addDays(from, d)),
      for (var d = 0; d < 5; d++) log(doseItem, addDays(from, d)),
      log(doseItem, addDays(from, 5), status: CareLogStatus.skipped),
    ],
  );
}

HealthRecord rabies(DateTime on) => HealthRecord(
  id: 'r',
  petId: 'kelly',
  kind: RecordKind.vaccination,
  title: 'Rabies vaccine',
  scheduledAt: DateTime(on.year, on.month, on.day, 9),
);

/// Records the groups a scheduler sends.
class RecordingSink implements NotificationSink {
  final groups = <String, List<PlannedNotification>>{};

  @override
  Future<void> syncGroup(String group, List<PlannedNotification> items) async => groups[group] = items;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('weeks start on the chosen first day', () {
    final wednesday = DateTime(2026, 10, 21);
    expect(weekStartOf(wednesday, DateTime.sunday), sunday);
    expect(weekStartOf(wednesday, DateTime.monday), DateTime(2026, 10, 19));
    expect(weekStartOf(sunday, DateTime.sunday), sunday);
    expect(weekStartOf(sunday, DateTime.monday), DateTime(2026, 10, 12));
  });

  test('the week before the summary: walks done of planned, doses given', () {
    final numbers = weekNumbers(
      plan: lastWeek(),
      records: [rabies(DateTime(2026, 11, 8))],
      ringDay: sunday,
      today: sunday,
      firstDay: DateTime.sunday,
    );
    expect(numbers.from, DateTime(2026, 10, 11));
    expect(numbers.to, sunday);
    expect((numbers.walksDone, numbers.walksPlanned), (5, 7));
    expect((numbers.dosesGiven, numbers.dosesPlanned), (5, 7));
    expect(numbers.nextDue?.title, 'Rabies vaccine');
    expect(numbers.isEmpty, isFalse);
  });

  test('composed ahead of time, only the days already passed count', () {
    final numbers = weekNumbers(
      plan: lastWeek(),
      records: const [],
      ringDay: sunday,
      today: DateTime(2026, 10, 14),
      firstDay: DateTime.sunday,
    );
    expect((numbers.walksDone, numbers.walksPlanned), (2, 3));
  });

  test('no routine, no medicine, nothing planned: nothing to say', () {
    final numbers = weekNumbers(
      plan: const CarePlan(),
      records: const [],
      ringDay: sunday,
      today: sunday,
      firstDay: DateTime.sunday,
    );
    expect(numbers.isEmpty, isTrue);
    expect(weeklyBody(en, numbers, sunday), isNull);
  });

  test('the next weekday and time, never now or in the past', () {
    final saturday = DateTime(2026, 10, 17, 20);
    expect(nextWeeklyAt(saturday, DateTime.sunday, 9 * 60), DateTime(2026, 10, 18, 9));
    expect(nextWeeklyAt(DateTime(2026, 10, 18, 9), DateTime.sunday, 9 * 60), DateTime(2026, 10, 25, 9));
    expect(nextWeeklyAt(DateTime(2026, 10, 18, 8, 59), DateTime.sunday, 9 * 60), DateTime(2026, 10, 18, 9));
    expect(nextWeeklyAt(saturday, DateTime.wednesday, 18 * 60 + 30), DateTime(2026, 10, 21, 18, 30));
  });

  test('the wording, in English and Hebrew', () {
    final numbers = weekNumbers(
      plan: lastWeek(),
      records: [rabies(DateTime(2026, 11, 8))],
      ringDay: sunday,
      today: sunday,
      firstDay: DateTime.sunday,
    );
    expect(
      weeklyBody(en, numbers, sunday),
      'Last week: 5 of 7 walks · 5 of 7 doses given\nRabies vaccine due in 3 weeks',
    );
    final hebrew = weeklyBody(he, numbers, sunday)!;
    expect(hebrew, contains('בשבוע שעבר'));
    expect(hebrew, contains('5 מתוך 7 טיולים'));
    expect(hebrew, contains('בעוד 3 שבועות'));
    expect(en.weeklyTitle('Kelly'), "Kelly's week");
    expect(he.weeklyTitle('Kelly'), contains('השבוע של'));

    String due(int days) => dueLine(en, rabies(addDays(sunday, days)), sunday);
    expect(due(0), 'Rabies vaccine is due today');
    expect(due(1), 'Rabies vaccine is due tomorrow');
    expect(due(5), 'Rabies vaccine due in 5 days');
    expect(due(7 * 8), 'Rabies vaccine due in 8 weeks');
    expect(due(100), 'Rabies vaccine due on 26.01.27');
    expect(dueLine(he, rabies(addDays(sunday, 14)), sunday), contains('בעוד שבועיים'));
  });

  test('walks without a routine are counted as logged', () {
    final extra = CareLog(
      id: 'x',
      petId: 'kelly',
      title: 'Walk',
      dueOn: DateTime(2026, 10, 12),
      status: CareLogStatus.done,
      loggedAt: DateTime(2026, 10, 12),
      kind: CareKind.walk,
      minutes: 30,
    );
    final numbers = weekNumbers(
      plan: CarePlan(logs: [extra]),
      records: const [],
      ringDay: sunday,
      today: sunday,
      firstDay: DateTime.sunday,
    );
    expect(weeklyBody(en, numbers, sunday), 'Last week: 1 walk');
  });

  test('the demo: counted on the sample data\'s days, ringing in the real '
      'world', () {
    final planned = planWeeklySummary(
      petId: 'kelly',
      petName: 'Kelly',
      plan: lastWeek(),
      records: const [],
      // The real clock is a year later than the data: a Sunday morning.
      now: DateTime(2027, 10, 17, 8),
      dataToday: DateTime(2026, 10, 18, 8),
      settings: NotificationSettings.defaults,
      firstDay: DateTime.sunday,
      l10n: en,
    )!;
    expect(planned.at, DateTime(2027, 10, 17, 9));
    expect(planned.kind, NotificationKind.weekly);
    expect(planned.title, "Kelly's week");
    expect(planned.payload, 'health:kelly');
    expect(planned.done, isNull, reason: 'nothing to tick');
    expect(planned.body, startsWith('Last week: 5 of 7 walks'));
  });

  test('the scheduler keeps one summary per pet and follows the choices', () async {
    final sink = RecordingSink();
    var settings = NotificationSettings.defaults;
    var allowed = true;
    final scheduler = WeeklySummaryScheduler(
      sink: sink,
      strings: () => en,
      settings: () => settings,
      firstDay: () => DateTime.sunday,
      allowed: () => allowed,
      now: () => DateTime(2026, 10, 17, 12),
    );
    await scheduler.sync(
      petId: 'kelly',
      petName: 'Kelly',
      plan: lastWeek(),
      records: const [],
      dataToday: DateTime(2026, 10, 17, 12),
    );
    expect(sink.groups['week:kelly']!.single.at, DateTime(2026, 10, 18, 9));

    // Wednesday at 20:00 instead.
    settings = settings.copyWith(weeklyDay: DateTime.wednesday, weeklyMinutes: 20 * 60);
    await scheduler.replanAll();
    expect(sink.groups['week:kelly']!.single.at, DateTime(2026, 10, 21, 20));

    // The records could not be loaded this time: the last ones are used.
    await scheduler.sync(petId: 'kelly', petName: 'Kelly', plan: lastWeek(), records: null, dataToday: DateTime(2026, 10, 17));
    expect(sink.groups['week:kelly'], hasLength(1));

    // Without the capability: none.
    allowed = false;
    await scheduler.replanAll();
    expect(sink.groups['week:kelly'], isEmpty);

    allowed = true;
    await scheduler.forget('kelly');
    await scheduler.replanAll();
    expect(sink.groups['week:kelly'], isEmpty);
  });

  test('the switch and its day and time are remembered on the phone', () async {
    final store = MemorySettingsStore({
      notificationKindSettingKey(NotificationKind.weekly): '0',
      weeklyDaySettingKey: '3',
      weeklyTimeSettingKey: '20:30',
    });
    expect(NotificationSettings.defaults.weekly, isTrue);
    expect(NotificationSettings.defaults.weeklyDayOr(DateTime.sunday), DateTime.sunday);
    expect(NotificationSettings.defaults.weeklyMinutes, 9 * 60);
    expect(NotificationSettings.waitsInQuietHours(NotificationKind.weekly), isTrue);
    final container = ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    final read = container.read(notificationSettingsProvider);
    expect((read.weekly, read.weeklyDay, read.weeklyMinutes), (false, 3, 20 * 60 + 30));
    await container.read(notificationSettingsProvider.notifier).setWeeklyTime(day: 5, minutes: 7 * 60);
    expect(container.read(notificationSettingsProvider).weeklyDayOr(DateTime.sunday), 5);
    expect(store.values[weeklyDaySettingKey], '5');
    expect(store.values[weeklyTimeSettingKey], '07:00');
    // Something unreadable falls back to the defaults.
    store.values[weeklyTimeSettingKey] = '25:99';
    store.values[weeklyDaySettingKey] = '9';
    container.invalidate(notificationSettingsProvider);
    final fallback = container.read(notificationSettingsProvider);
    expect((fallback.weeklyDay, fallback.weeklyMinutes), (null, 9 * 60));
  });
}
