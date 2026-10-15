import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/today/today_card.dart';

import 'helpers.dart';

/// How the Pets feature is wired into the Home dashboard and the Health
/// tab (which has no reminder of its own), in the app as shipped (demo account: Kelly is complete, Soya is
/// missing her essentials).
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the "+" on Home opens the add-a-pet flow', (tester) async {
    await pumpHome(tester);

    // The pet row scrolls sideways, and in the wide test font the "+" starts
    // outside it: drag the row itself (not the page) to bring it into view.
    final add = find.bySemanticsLabel('Add a pet');
    await tester.drag(find.text('Soya'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, add);

    expect(find.text('Who is joining the family?'), findsOneWidget);
  });

  testWidgets('Home reminds about missing essentials for Soya and not for Kelly', (tester) async {
    await pumpHome(tester);

    // Kelly is complete; Soya's reminder is a row of the Today list,
    // whichever pet is selected.
    expect(find.text("Finish Kelly's profile"), findsNothing);
    expect(find.byKey(TodayCard.rowKey('essentials:kelly')), findsNothing);
    final row = find.byKey(TodayCard.rowKey('essentials:soya'));
    expect(find.descendant(of: row, matching: find.text("Finish Soya's profile")), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('essentials still to add')), findsOneWidget);

    // "Remind me in a week" in the checklist puts the row away; the
    // dashboard is still there.
    // Centred: at the top of Home it would sit under the pinned bar.
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await tester.pumpAndSettle();
    await tapAndSettle(tester, row);
    await tester.ensureVisible(find.text('Remind me in a week'));
    await tapAndSettle(tester, find.text('Remind me in a week'));
    expect(find.text("Finish Soya's profile"), findsNothing);
    expect(find.text('Feeding'), findsOneWidget);
  });

  testWidgets('tapping the pet picture on Home opens the pet profile', (tester) async {
    await pumpHome(tester);

    await tapAndSettle(tester, find.bySemanticsLabel("Kelly's picture").last);

    // The profile is a full page over the tabs.
    expect(find.text('Feeding'), findsNothing);
    expect(find.textContaining('Kelly'), findsWidgets);
  });

  testWidgets('the Health overview has no reminder card: the one nag is on Home', (tester) async {
    await pumpHome(tester);
    await tapAndSettle(tester, find.text('Soya'));
    expect(find.byKey(TodayCard.rowKey('essentials:soya')), findsOneWidget);

    // "Health" is also the title of a dashboard card; the tab is the last.
    await tapAndSettle(tester, find.text('Health').last);

    expect(find.text('Overview'), findsWidgets);
    expect(find.byKey(TodayCard.rowKey('essentials:soya')), findsNothing);
    expect(find.textContaining('essentials still to add'), findsNothing);
    expect(find.text("Finish Soya's profile"), findsNothing);
  });
}
