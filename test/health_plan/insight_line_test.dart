import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/insights/insight_line.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/insights/insight_providers.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/state/health_providers.dart';

import '../health/health_test_helpers.dart';

/// Three "ate less than usual" entries in the 14 days before [fixedNow].
Future<FakeHealthRepository> lessAppetite(WidgetTester tester, {bool seeded = true}) async {
  final repo = fakeHealth(seeded: seeded);
  await real(tester, () async {
    for (final daysAgo in [12, 6, 1]) {
      await repo.saveObservation(
        Observation(
          id: '',
          petId: 'kelly',
          category: 'appetite',
          level: ObservationLevel.less,
          observedAt: addDays(fixedNow, -daysAgo),
        ),
      );
    }
  });
  return repo;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final line = find.byKey(HealthInsightLine.lineKey);

  testWidgets('the Overview opens with one calm line and its link', (tester) async {
    final h = await pumpHealth(tester, harness: HealthHarness(repository: await lessAppetite(tester)));
    expect(line, findsOneWidget);
    final l10n = lookupHealthPlanL10n(englishLocale);
    expect(find.text(l10n.insightAppetiteLess('Kelly', 3)), findsOneWidget);
    expect(find.text(l10n.insightSeeJournal), findsOneWidget);
    // Shown this week: remembered on the phone.
    expect(h.settings.values[insightShownKey('kelly')], '2025-W24|appetiteLess');

    await tapVisible(tester, find.byKey(HealthInsightLine.linkKey));
    final container = hostContainer(tester);
    expect(container.read(healthSectionProvider), HealthSection.records);
    expect(container.read(historyFilterProvider).view, RecordsView.journal);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another insight that week stays hidden', (tester) async {
    final harness = HealthHarness(repository: await lessAppetite(tester));
    harness.settings.values[insightShownKey('kelly')] = '2025-W24|weightDown';
    await pumpHealth(tester, harness: harness);
    expect(line, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing to say, nothing shown', (tester) async {
    await pumpHealth(tester, harness: HealthHarness(repository: fakeHealth(seeded: false)));
    expect(line, findsNothing);
  });

  testWidgets('without the capability, no line', (tester) async {
    final harness = HealthHarness(repository: await lessAppetite(tester));
    await pumpHealth(tester, harness: harness, openTab: false);
    final container = hostContainer(tester);
    final access = container.read(accessRepositoryProvider) as FakeAccessRepository;
    access.groups['standard']!.remove(insightsCapability);
    await container.read(accessProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await openHealthTab(tester);
    expect(line, findsNothing);
  });

  testWidgets('in Hebrew, right to left', (tester) async {
    final h = await pumpHealth(tester, harness: hebrewHealth(repository: await lessAppetite(tester)), size: smallPhone);
    final l10n = lookupHealthPlanL10n(hebrewLocale);
    expect(find.text(l10n.insightAppetiteLess('Kelly', 3)), findsOneWidget);
    expect(directionOf(tester, line), TextDirection.rtl);
    expect(hasHebrew(l10n.insightSeeJournal), isTrue);
    expect(h.isHebrew, isTrue);
    expect(tester.takeException(), isNull);
  });
}
