import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'household_screen.dart';
import 'join_screen.dart';

/// The Household pages: full screen, beside the tabs.
abstract final class HouseholdRoutes {
  static const household = '/household';

  /// The join page; `/join/<code>` is the invitation link's path.
  static const join = '/join';
  static String joinCode(String code) => '$join/$code';
}

final householdRoutes = <RouteBase>[
  GoRoute(
    path: HouseholdRoutes.household,
    builder: (context, state) => const HouseholdScreen(),
  ),
  GoRoute(
    path: HouseholdRoutes.join,
    builder: (context, state) => const JoinHouseholdScreen(),
  ),
  GoRoute(
    path: '${HouseholdRoutes.join}/:code',
    builder: (context, state) =>
        JoinHouseholdScreen(code: state.pathParameters['code']),
  ),
];

/// Opens the Household page above the current one.
Future<void> openHousehold(BuildContext context) =>
    _push(context, HouseholdRoutes.household, (_) => const HouseholdScreen());

/// Opens the join page, with [code] filled in when there is one.
Future<void> openJoinHousehold(BuildContext context, {String? code}) => _push(
  context,
  code == null ? HouseholdRoutes.join : HouseholdRoutes.joinCode(code),
  (_) => JoinHouseholdScreen(code: code),
);

Future<void> _push(
  BuildContext context,
  String location,
  WidgetBuilder builder,
) async {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push<void>(location);
  } else {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push<void>(MaterialPageRoute(builder: builder));
  }
}
