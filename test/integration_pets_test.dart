import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/pets.dart';

import 'helpers.dart';

/// How the Pets feature is wired into the Home dashboard and the Health
/// tab, in the app as shipped (demo account: Kelly is complete, Soya is
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

    // Kelly is complete: the reminder is in the tree but draws nothing.
    expect(find.text('Not now'), findsNothing);

    await tapAndSettle(tester, find.text('Soya'));
    expect(find.text('Not now'), findsOneWidget);
    expect(find.textContaining('essentials still to add'), findsOneWidget);

    // "Not now" puts the line away; the dashboard is still there.
    await tapAndSettle(tester, find.text('Not now'));
    expect(find.text('Not now'), findsNothing);
    expect(find.text('Feeding'), findsOneWidget);
  });

  testWidgets('tapping the pet picture on Home opens the pet profile', (tester) async {
    await pumpHome(tester);

    await tapAndSettle(tester, find.bySemanticsLabel("Kelly's picture").last);

    // The profile is a full page over the tabs.
    expect(find.text('Feeding'), findsNothing);
    expect(find.textContaining('Kelly'), findsWidgets);
  });

  testWidgets('the Health overview shows the reminder card for Soya', (tester) async {
    await pumpHome(tester);
    await tapAndSettle(tester, find.text('Soya'));

    // "Health" is also the title of a dashboard card; the tab is the last.
    await tapAndSettle(tester, find.text('Health').last);

    expect(find.byType(PetReminderCard), findsOneWidget);
    expect(find.textContaining('essentials still to add'), findsOneWidget);
  });
}
