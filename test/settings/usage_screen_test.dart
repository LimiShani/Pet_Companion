import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/settings/admin_tools_screen.dart';
import 'package:pet_companion/features/settings/usage_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/platform/usage.dart';
import 'package:pet_companion/platform/usage_summary.dart';

import '../helpers.dart';
import 'settings_test_helpers.dart';

final today = DateTime(2026, 10, 15);

UsageSummary sample() => UsageSummary([
  for (var i = 0; i < 28; i++)
    UsageDay(
      day: DateTime(today.year, today.month, today.day - i),
      active: i == 0 ? 4 : (i < 10 ? 2 : 0),
      todayTickShare: i == 0 ? 0.75 : (i < 10 ? 0.5 : 0),
      kinds: {
        if (i < 10)
          UsageKind.careLogged: UsageKindDay(accounts: 2, total: i == 0 ? 9 : 3),
      },
    ),
]);

/// [screen] on its own, with the Usage page reading [repository].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  UsageSummaryRepository? repository,
  bool admin = true,
  AppLanguage language = AppLanguage.english,
}) async {
  tester.view.physicalSize = phone * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        usageSummaryRepositoryProvider.overrideWithValue(
          repository ?? FakeUsageSummaryRepository(latency: Duration.zero, summary: sample()),
        ),
        capabilityProvider.overrideWith((ref, capability) => admin && capability == 'access.admin'),
      ],
      child: MaterialApp(
        locale: language == AppLanguage.hebrew ? hebrewLocale : englishLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final l10n = stringsOf(AppLanguage.english);

  testWidgets('an administrator finds Usage in Admin tools and opens it', (tester) async {
    await pumpApp(
      tester,
      overrides: [
        usageSummaryRepositoryProvider.overrideWithValue(
          FakeUsageSummaryRepository(latency: Duration.zero, summary: sample()),
        ),
      ],
    );
    await signInAsDemo(tester);
    await settle(tester);
    await openAdminTools(tester, l10n);

    expect(find.byKey(AdminToolsScreen.usageKey), findsOneWidget);
    expect(find.text(l10n.adminUsage), findsOneWidget);
    await tester.tap(find.byKey(AdminToolsScreen.usageKey));
    await settle(tester);
    expect(find.byKey(UsageScreen.screenKey), findsOneWidget);
    expect(find.text(l10n.usageTitle), findsOneWidget);
    expect(find.byKey(UsageScreen.dayKey(today)), findsOneWidget);
  });

  testWidgets('an account that is not an administrator has no Usage row', (tester) async {
    await pumpScreen(tester, const AdminToolsScreen(), admin: false);
    expect(find.byKey(AdminToolsScreen.screenKey), findsOneWidget);
    expect(find.byKey(AdminToolsScreen.usageKey), findsNothing);
    expect(find.byKey(AdminToolsScreen.featureAccessKey), findsNothing);
  });

  testWidgets('an administrator has the Usage row next to Feature access', (tester) async {
    await pumpScreen(tester, const AdminToolsScreen());
    expect(find.byKey(AdminToolsScreen.featureAccessKey), findsOneWidget);
    expect(find.byKey(AdminToolsScreen.usageKey), findsOneWidget);
    expect(find.text(l10n.adminUsageSummary), findsOneWidget);
  });

  testWidgets('the table shows each day, newest first, then the kinds with their totals', (tester) async {
    await pumpScreen(tester, const UsageScreen());

    final first = find.byKey(UsageScreen.dayKey(today));
    expect(find.descendant(of: first, matching: find.text('15.10.26')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('4')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('75%')), findsOneWidget);
    final second = find.byKey(UsageScreen.dayKey(DateTime(2026, 10, 14)));
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(find.descendant(of: second, matching: find.text('50%')), findsOneWidget);

    final care = find.byKey(UsageScreen.kindKey(UsageKind.careLogged));
    await tester.scrollUntilVisible(care, 300);
    await tester.pumpAndSettle();
    // 7 days: 9 + 6 × 3; 28 days: 9 + 9 × 3.
    expect(find.descendant(of: care, matching: find.text(l10n.usageKindCareLogged)), findsOneWidget);
    expect(find.descendant(of: care, matching: find.text('27')), findsOneWidget);
    expect(find.descendant(of: care, matching: find.text('36')), findsOneWidget);

    final opened = find.byKey(UsageScreen.kindKey(UsageKind.appOpened));
    await tester.scrollUntilVisible(opened, 300);
    await tester.pumpAndSettle();
    expect(find.descendant(of: opened, matching: find.text('0')), findsNWidgets(2));
  });

  testWidgets('a day without counts shows a dash instead of a share', (tester) async {
    await pumpScreen(tester, const UsageScreen());
    final quiet = find.byKey(UsageScreen.dayKey(DateTime(2026, 9, 18)));
    await tester.scrollUntilVisible(quiet, 300);
    await tester.pumpAndSettle();
    expect(find.descendant(of: quiet, matching: find.text('-')), findsOneWidget);
  });

  testWidgets('fits a small phone in Hebrew', (tester) async {
    await pumpScreen(tester, const UsageScreen(), language: AppLanguage.hebrew);
    tester.view.physicalSize = smallPhone * 3;
    await tester.pumpAndSettle();
    final he = stringsOf(AppLanguage.hebrew);
    expect(find.text(he.usageTitle), findsOneWidget);
    expect(find.text(he.usageColumnTicks), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no counts yet: the empty state', (tester) async {
    await pumpScreen(
      tester,
      const UsageScreen(),
      repository: FakeUsageSummaryRepository(
        latency: Duration.zero,
        summary: UsageSummary([UsageDay(day: today, active: 0, todayTickShare: 0)]),
      ),
    );
    expect(find.text(l10n.usageEmptyTitle), findsOneWidget);
    expect(find.text(l10n.usageEmptyMessage), findsOneWidget);
    expect(find.byKey(UsageScreen.daysKey), findsNothing);
  });

  testWidgets('a failed load: the error state, and Try again loads again', (tester) async {
    final failing = _SwitchableRepository();
    await pumpScreen(tester, const UsageScreen(), repository: failing);
    expect(find.text(l10n.usageErrorTitle), findsOneWidget);

    failing.fails = false;
    await tester.tap(find.text(l10n.commonTryAgain));
    await tester.pumpAndSettle();
    expect(find.text(l10n.usageErrorTitle), findsNothing);
    expect(find.byKey(UsageScreen.daysKey), findsOneWidget);
    expect(failing.calls, 2);
  });

  testWidgets('the demo shows sample numbers', (tester) async {
    await pumpScreen(
      tester,
      const UsageScreen(),
      repository: FakeUsageSummaryRepository(latency: Duration.zero, now: () => today),
    );
    expect(find.byKey(UsageScreen.dayKey(today)), findsOneWidget);
    expect(find.text(l10n.usageEmptyTitle), findsNothing);
  });
}

class _SwitchableRepository implements UsageSummaryRepository {
  bool fails = true;
  int calls = 0;

  @override
  Future<UsageSummary> fetch({int days = 28}) async {
    calls++;
    if (fails) throw StateError('backend down');
    return sample();
  }
}
