import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/l10n/l10n.dart';

import 'helpers.dart';

void main() {
  setUpAll(() {
    // No network in tests: fall back to the platform font quietly.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // The sample day, in the afternoon: breakfast and a morning walk are
  // logged, dinner and the evening walk are still to come.
  final afternoon = DateTime(2025, 6, 10, 15);

  Future<void> pumpHome(WidgetTester tester) async {
    await pumpApp(tester, now: afternoon);
    await signInAsDemo(tester);
  }

  testWidgets('home shows Kelly with her dashboard', (tester) async {
    await pumpHome(tester);

    // The title is announced by name; how much of it is drawn depends on
    // the room the Emergency pill leaves (see test/home/).
    expect(find.bySemanticsLabel('PetLoop'), findsOneWidget);
    expect(find.text('2 pets'), findsOneWidget);
    expect(find.text('Kelly'), findsNWidgets(2)); // selector pill + hero name
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('23 kg'), findsOneWidget);
    // Breakfast: 140 g of a food with 360 cal per 100 g. The goal is the
    // estimate for 23 kg at 13.6 years: 70 × 23^0.75 × 1.4, in tens.
    expect(find.text('504'), findsOneWidget);
    expect(find.text('Goal 1,030 cal/day'), findsOneWidget);
    expect(find.text('Next feeding · 19:30'), findsOneWidget);
    // The morning walk (25 min) is done; the evening walk is planned.
    expect(find.text(isolate('1/2')), findsOneWidget);
    expect(find.text(isolate('25')), findsOneWidget);
    expect(find.text('Next walk · 18:30'), findsOneWidget);
    // Tonight's joint tablet comes before the planned check-up.
    expect(find.text('Medicine: Joint tablets'), findsOneWidget);
    expect(find.text('Today · 20:00'), findsOneWidget);
    expect(find.text('General check'), findsOneWidget);
    expect(find.text('12.06.25 · 18:20'), findsOneWidget);
  });

  testWidgets('tapping Soya switches the dashboard', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Soya'));
    await tester.pumpAndSettle();

    expect(find.text('Soya'), findsNWidgets(2));
    expect(find.text('Mix'), findsNothing);
    // Nothing set up yet: invitations rather than zeros.
    expect(find.text('No goal set'), findsOneWidget);
    expect(find.text('Add the food to count calories'), findsOneWidget);
    expect(find.text('Next feeding · not set'), findsOneWidget);
    expect(find.text('No health events yet'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    expect(find.text('Search deals'), findsOneWidget); // the Store tab's search field

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Feeding'), findsOneWidget);
  });
}
