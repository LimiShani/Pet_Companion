import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// The phone's back button, as the system delivers it.
  Future<bool> pressBack(WidgetTester tester) async {
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    return handled;
  }

  testWidgets('back at the root of a tab other than Home goes to Home', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);

    for (final tab in ['Health', 'Community', 'Store']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text('Feeding'), findsNothing, reason: tab);

      expect(await pressBack(tester), isTrue, reason: tab);
      expect(find.text('Feeding'), findsOneWidget, reason: tab);
    }
  });

  testWidgets('back closes a page inside a tab before anything else', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squeaky rope tug toy, 2 pack'));
    await tester.pumpAndSettle();
    expect(find.text('Search deals'), findsNothing);

    expect(await pressBack(tester), isTrue);
    expect(find.text('Search deals'), findsOneWidget);

    expect(await pressBack(tester), isTrue);
    expect(find.text('Feeding'), findsOneWidget);
  });

  testWidgets('back on Home leaves the app', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
    // Not handled by the app: the system closes it.
    expect(await pressBack(tester), isFalse);
    expect(find.text('Feeding'), findsOneWidget);
  });

  testWidgets('the system is told back is handled away from Home (predictive back)', (tester) async {
    // What the app tells Android about the back button; Android 14+ closes
    // the app on back unless the last word was "handled".
    final said = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') said.add(call.arguments as bool);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    // Flutter only reports while the app is in the foreground.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpApp(tester);
    await signInAsDemo(tester);
    expect(said, isNotEmpty);
    expect(said.last, isFalse, reason: 'Home: back leaves the app');

    await tester.tap(find.text('Health').last);
    await tester.pumpAndSettle();
    expect(said.last, isTrue, reason: 'Health: back goes to Home');

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squeaky rope tug toy, 2 pack'));
    await tester.pumpAndSettle();
    await pressBack(tester);
    expect(said.last, isTrue, reason: 'Store list: back goes to Home');

    await pressBack(tester);
    expect(find.text('Feeding'), findsOneWidget);
    expect(said.last, isFalse, reason: 'Home again');
  });
}
