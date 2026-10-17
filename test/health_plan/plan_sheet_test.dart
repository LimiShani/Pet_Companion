import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/health/plans/plan_invite.dart';
import 'package:pet_companion/features/health/plans/yearly_plan_sheet.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/pet_records/plans/plan_calendar.dart';
import 'package:pet_companion/services/pet_records/plans/plan_providers.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/widgets/add_sheet.dart';

import '../health/health_test_helpers.dart';

final _en = lookupHealthPlanL10n(englishLocale);
final _he = lookupHealthPlanL10n(hebrewLocale);

/// A puppy of 9 weeks on [fixedNow] (10 June 2025) with nothing on record.
final puppy = Pet(id: 'kelly', name: 'Kelly', birthDate: DateTime(2025, 4, 8));
const soya = Pet(id: 'soya', name: 'Soya', species: PetSpecies.cat, ageYears: 5);

final sheet = find.byKey(YearlyPlanSheet.sheetKey);

Future<void> openPlanRow(WidgetTester tester) => openAddRow(tester, 'yearly-plan');

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('the "+" row opens the plan; an item already planned is shown '
      'and never planned twice', (tester) async {
    final h = await pumpHealth(tester);
    await openPlanRow(tester);
    expect(sheet, findsOneWidget);
    expect(find.text(_en.planTitle('Kelly')), findsOneWidget);
    expect(find.text(_en.planIntroDog), findsOneWidget);
    // The sample data plans Kelly's rabies booster for 14.03.26.
    expect(find.text(_en.planAlreadyPlanned('14.03.26')), findsOneWidget);
    expect(find.text(_en.planRequired), findsOneWidget);
    expect(find.text(_en.planNoHistory), findsWidgets);
    // Four items to add: rabies is already planned.
    expect(find.text(_en.planAddDates(4)), findsOneWidget);

    // Unticking one and choosing three months for fleas.
    await tapVisible(tester, find.byKey(YearlyPlanSheet.itemKey('dog.spirocerca')));
    expect(find.text(_en.planAddDates(3)), findsOneWidget);
    await tapVisible(tester, find.byKey(YearlyPlanSheet.monthsKey('dog.flea', 3)));
    // The last flea tablet was on 27.05.25: three months on.
    expect(find.text(_en.planFirstDate('27.08.25')), findsOneWidget);

    final before = (await real(tester, () => h.repository.fetchRecords('kelly'))).length;
    await tapVisible(tester, find.byKey(YearlyPlanSheet.addKey));
    expect(find.byKey(YearlyPlanSheet.addedKey), findsOneWidget);
    expect(find.text(_en.planAdded('Kelly')), findsOneWidget);
    expect(find.text(_en.planAddedNote(3)), findsOneWidget);
    final records = await real(tester, () => h.repository.fetchRecords('kelly'));
    expect(records.length, before + 3);
    expect(
      records.where((r) => r.isFromPlan).map((r) => r.planItem),
      unorderedEquals(['dog.combined', 'dog.deworm', 'dog.flea@3m']),
    );

    // The dates go to the calendar as one .ics file.
    await tapVisible(tester, find.byKey(YearlyPlanSheet.calendarKey));
    final file = h.sharer.shared.single;
    expect(file.name, endsWith('.ics'));
    expect(file.mimeType, 'text/calendar');
    final ics = utf8.decode(file.bytes);
    expect('BEGIN:VEVENT'.allMatches(ics), hasLength(3));
    expect(ics, contains('TRIGGER:-P1D'));
    expect(ics, contains('DTSTART:20250827T090000'));
    expect(ics, contains('DTEND:20250827T093000'));
    expect(ics, isNot(contains('RRULE')));

    await tapVisible(tester, find.byKey(YearlyPlanSheet.doneKey));
    expect(sheet, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a puppy: its series, the Overview invitation, and "from the '
      'plan" in Coming up', (tester) async {
    final h = HealthHarness(repository: fakeHealth(seeded: false), pets: [puppy, soya]);
    await pumpHealth(tester, harness: h);
    expect(find.byKey(PlanInviteCard.cardKey), findsOneWidget);
    expect(find.text(_en.planInvite('Kelly')), findsOneWidget);

    await tapVisible(tester, find.byKey(PlanInviteCard.actionKey));
    expect(find.text('Combined vaccine, puppy dose 1 of 3'), findsOneWidget);
    expect(find.text(_en.planSeriesTwo(12, 16)), findsOneWidget);
    expect(find.text(_en.planFromMonths(3)), findsWidgets);
    await tapVisible(tester, find.byKey(YearlyPlanSheet.addKey));
    await tapVisible(tester, find.byKey(YearlyPlanSheet.doneKey));

    // The first dose is today: Coming up names the plan; the invitation
    // goes once a vaccination is on record.
    expect(find.byKey(const Key('overview-from-plan')), findsOneWidget);
    expect(find.text(_en.planFromPlan('Kelly')), findsOneWidget);
    expect(find.byKey(PlanInviteCard.cardKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sources of the plan', (tester) async {
    await pumpHealth(tester);
    await openPlanRow(tester);
    await tapVisible(tester, find.byKey(YearlyPlanSheet.sourcesKey));
    expect(find.text(_en.planSources), findsWidgets);
    expect(find.textContaining('WSAVA'), findsWidgets);
    expect(find.textContaining('Veterinary Services'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without the capability: no row and no invitation', (tester) async {
    final h = HealthHarness(repository: fakeHealth(seeded: false), pets: [puppy, soya]);
    await pumpHealth(tester, harness: h, openTab: false);
    final container = hostContainer(tester);
    (container.read(accessRepositoryProvider) as FakeAccessRepository).groups['standard']!.remove(plansCapability);
    await container.read(accessProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await openHealthTab(tester);
    expect(find.byKey(PlanInviteCard.cardKey), findsNothing);
    await tester.tap(find.byKey(AddFab.fabKey));
    await tester.pumpAndSettle();
    expect(find.byKey(AddSheet.rowKey('yearly-plan')), findsNothing);
  });

  testWidgets('in Hebrew, right to left', (tester) async {
    final h = hebrewHealth(repository: fakeHealth(seeded: false), pets: [puppy, soya]);
    await pumpHealth(tester, harness: h, size: smallPhone);
    await openPlanRow(tester);
    expect(find.text(_he.planTitle('Kelly')), findsOneWidget);
    expect(find.text('חיסון משושה, מנת גור 1 מתוך 3'), findsOneWidget);
    expect(directionOf(tester, sheet), TextDirection.rtl);
    await tapVisible(tester, find.byKey(YearlyPlanSheet.addKey));
    expect(find.text(_he.planAdded('Kelly')), findsOneWidget);
    final records = await real(tester, () => h.repository.fetchRecords('kelly'));
    expect(records.map((r) => r.title), contains('חיסון כלבת'));
    expect(tester.takeException(), isNull);
  });

  test('the calendar file: escaped, folded, CRLF, one alarm per event', () {
    final records = [
      HealthRecord(
        id: 'r1',
        petId: 'kelly',
        kind: RecordKind.vaccination,
        title: 'Rabies vaccine',
        scheduledAt: DateTime(2026, 3, 14, 9),
        planItem: 'dog.rabies',
      ),
    ];
    final ics = planCalendar(
      records,
      summary: (r) => '${r.title}, Kelly; a long name that goes on and on past the line limit of the format',
      description: 'From Kelly\'s yearly plan',
      stamp: DateTime.utc(2026, 1, 1, 12),
    );
    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
    expect(ics, contains('UID:r1@petloop.app'));
    expect(ics, contains('DTSTAMP:20260101T120000Z'));
    expect(ics, contains(r'Rabies vaccine\, Kelly\; a long'));
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
    }
    expect(ics.split('\r\n').where((l) => l.startsWith(' ')), isNotEmpty);
    expect(ics.replaceAll('\r\n', '').contains('\n'), isFalse);
  });
}
