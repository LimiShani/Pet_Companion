import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/feed/post_card.dart';
import 'package:pet_companion/features/health/sections/history_section.dart';
import 'package:pet_companion/features/health/sections/insights_section.dart';
import 'package:pet_companion/features/health/sections/schedule_section.dart';
import 'package:pet_companion/features/store/widgets/deal_card.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/empty_state.dart';

import '../health/health_test_helpers.dart';
import '../helpers.dart';
import '../store/store_test_helpers.dart' show pumpStore;

/// The extended floating buttons of Health, Community and Store never sit
/// on top of the last row once the list is scrolled to its end.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Scrolls the vertical list [inside] (the list or something in it) to
  /// its very end, and checks that there was something to scroll.
  Future<void> scrollToEnd(WidgetTester tester, Finder inside) async {
    final scrollable = find.ancestor(of: inside, matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0), reason: 'the list should be longer than the screen');
    // A lazy list only knows its full length once the end is built.
    do {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    } while (position.pixels < position.maxScrollExtent);
  }

  void expectAboveButton(WidgetTester tester, Finder last) {
    final button = tester.getRect(find.byType(FloatingActionButton));
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(button.top));
  }

  testWidgets('Health: every section with the Quick log button ends above it', (tester) async {
    await pumpHealth(tester);
    for (final (label, section) in [
      ('Schedule', find.byType(ScheduleSection)),
      ('History', find.byType(HistorySection)),
      ('Insights', find.byType(InsightsSection)),
    ]) {
      await openSection(tester, label);
      expect(find.byKey(const Key('quick-log-button')), findsOneWidget);
      await scrollToEnd(tester, section);
      expectAboveButton(tester, section);
    }
  });

  testWidgets('Community: the last post ends above "New post"', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
    await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text('Community')));
    await tester.pumpAndSettle();

    expect(find.text('New post'), findsOneWidget);
    await scrollToEnd(tester, find.byType(PostCard).first);
    expectAboveButton(tester, find.byType(PostCard).last);
  });

  testWidgets('Store: the last row of deals ends above "Share a deal"', (tester) async {
    await pumpStore(tester);

    await scrollToEnd(tester, find.byType(DealCard).first);
    expectAboveButton(tester, find.byType(DealCard).last);
  });

  testWidgets('Store: "no deals" keeps its button clear of "Share a deal" on a small phone', (tester) async {
    await pumpStore(tester);
    tester.view.physicalSize = const Size(320, 568) * 3;
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'no such thing anywhere');
    await tester.pumpAndSettle();

    final empty = find.byType(EmptyState);
    expect(empty, findsOneWidget);
    await scrollToEnd(tester, empty);
    expectAboveButton(tester, find.descendant(of: empty, matching: find.byType(FilledButton)));
  });
}
