import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/presentation/more_details.dart';

import 'health_test_helpers.dart';

/// Opens "More details" on the form on screen, unless it is open already.
Future<void> openMoreDetails(WidgetTester tester) async {
  if (tester.widget<MoreDetails>(find.byType(MoreDetails)).expanded) return;
  await tapVisible(tester, find.byKey(MoreDetails.toggleKey));
}
