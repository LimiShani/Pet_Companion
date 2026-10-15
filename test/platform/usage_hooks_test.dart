import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/state/store_providers.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/platform/usage.dart';

import '../helpers.dart';
import '../store/store_test_helpers.dart';
import 'usage_test.dart' show RecordingUsageSink;

/// The counter wired into the real app: signing in counts the day's
/// opening and sends it; a hook adds its kind to the tally.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('signing in sends the opening; opening a deal is counted', (tester) async {
    final sink = RecordingUsageSink();
    final now = DateTime(2026, 9, 30, 12);
    final usage = UsageCounter(
      sink: sink,
      userId: () => 'demo',
      store: MemorySettingsStore(),
      now: () => now,
    );
    await pumpApp(
      tester,
      overrides: [
        usageProvider.overrideWithValue(usage),
        storeClockProvider.overrideWithValue(() => fixedNow),
        storeRepositoryProvider.overrideWithValue(fakeStore()),
      ],
    );
    await signInAsDemo(tester);
    await tester.pumpAndSettle();
    expect(sink.sent, {
      '2026-09-30': {UsageKind.appOpened: 1},
    });

    await tester.tap(find.text(lookupAppL10n(englishLocale).navStore));
    await tester.pumpAndSettle();
    await openDeal(tester, 'd-salmon-kibble-12kg');
    expect(usage.pending('demo'), {
      '2026-09-30': {UsageKind.dealOpened: 1},
    });
    expect(sink.calls, 1, reason: 'Sent once a day');
  });
}
