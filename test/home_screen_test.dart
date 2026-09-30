import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers.dart';

void main() {
  setUpAll(() {
    // No network in tests: fall back to the platform font quietly.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
  }

  testWidgets('home shows Kelly with her dashboard', (tester) async {
    await pumpHome(tester);

    expect(find.text('Pet Companion'), findsOneWidget);
    expect(find.text('Kelly'), findsNWidgets(2)); // selector pill + hero name
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('23 kg'), findsOneWidget);
    expect(find.text('375'), findsOneWidget);
    expect(find.text('Goal 900 cal/day'), findsOneWidget);
    expect(find.text('Next feeding · 19:30'), findsOneWidget);
    expect(find.text('2,569'), findsOneWidget);
    expect(find.text('01:32'), findsOneWidget);
    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('27.07.25 · 19:30'), findsOneWidget);
  });

  testWidgets('tapping Soya switches the dashboard', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Soya'));
    await tester.pumpAndSettle();

    expect(find.text('Soya'), findsNWidgets(2));
    expect(find.text('Mix'), findsNothing);
    expect(find.text('No goal set'), findsOneWidget);
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
