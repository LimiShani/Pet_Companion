import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The parts of the app, each with its colour from the brand palette. The
/// colour sits on icon discs (`AreaDisc`), on tags (`AppTag.area`) and on
/// the bottom-bar icons; text is never coloured by area (ink or brown
/// only). The coral header stays coral everywhere, and yellow still means
/// "selected" for chips and segmented controls.
///
/// Outside shares [community]'s sage; Budget and the basket share
/// [store]'s yellow.
enum AppArea {
  /// Daily care: feeding, walks, routines, the pets themselves.
  care(AppColors.coralTint, AppColors.coralDeep),

  /// Health: records, medicines, vets, emergency.
  health(AppColors.peach, AppColors.peachDeep),

  /// Community and Outside: posts, chats, meetups, parks.
  community(AppColors.sage, AppColors.sageDeep),

  /// Store, Budget and the basket.
  store(AppColors.yellow, AppColors.yellowDeep),

  /// The account: settings, about, admin tools.
  you(AppColors.neutral, AppColors.neutralDeep);

  const AppArea(this.disc, this.deep);

  /// The fill of a disc, a tag or a selected bottom-bar pill (ink on it).
  final Color disc;

  /// The stroke of an unselected bottom-bar icon (3:1 on white).
  final Color deep;
}
