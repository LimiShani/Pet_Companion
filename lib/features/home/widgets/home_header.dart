import '../../../platform/feature_ui.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/pet_selector.dart';

/// The pinned top bar of the dashboard: branding, the Emergency pill for
/// the selected pet and the account avatar that opens the You page.
///
/// It stays in place while the dashboard scrolls under it, so the emergency
/// actions are always one tap away. The pill and everything it opens belong
/// to the Health feature; Home only places it.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.petId, this.raised = false});

  /// The pet the Emergency pill acts for.
  final String petId;

  /// True once the dashboard has scrolled under the bar: the bar then gets
  /// a rounded bottom edge and a shadow. At the top of the page it is
  /// square and flat, so it reads as one coral header with [HomePetRow].
  final bool raised;

  /// Height of the row: the full tap target of the Emergency pill.
  static const rowHeight = 48.0;
  static const _paddingTop = 8.0;
  static const _paddingBottom = 6.0;

  /// Height of the bar below the status-bar inset.
  static const height = _paddingTop + rowHeight + _paddingBottom;

  static const _gapBeforePill = 4.0;
  static const _gapAfterPill = 8.0;

  /// The two pieces of the logo, for tests.
  static const brandMarkKey = ValueKey('home-brand-mark');
  static const brandWordmarkKey = ValueKey('home-brand-wordmark');

  @override
  Widget build(BuildContext context) {
    // A Material (not a plain coloured box) so the ripples of the buttons
    // on it are visible.
    return Material(
      color: AppColors.coral,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.brown,
      elevation: raised ? 6 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(raised ? AppSpacing.shellRadius : 0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            _paddingTop,
            AppSpacing.screen,
            _paddingBottom,
          ),
          child: SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // The pill keeps its natural size and the title takes
                      // what is left. Only when the pill alone is wider than
                      // the room before the avatar (a tiny phone with very
                      // large text) is the pill scaled down to fit.
                      final pillRoom = math.max(
                        0.0,
                        constraints.maxWidth - _gapBeforePill,
                      );
                      return Row(
                        children: [
                          const Expanded(child: _Brand()),
                          const SizedBox(width: _gapBeforePill),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: pillRoom),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: featureSlot('emergency-button', petId),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: _gapAfterPill),
                const HeaderAvatar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The PetLoop logo, mark and lettering, shrinking to the room the
/// Emergency pill leaves: first the whole logo scales down, then the mark
/// is dropped so the lettering stays readable, and on the narrowest screens
/// only the mark remains.
class _Brand extends StatelessWidget {
  const _Brand();

  /// The app's name stays in Latin letters in every language.
  static const _name = 'PetLoop';
  static const _markSize = 28.0;
  static const _wordmarkHeight = 22.0;
  static const _gap = 6.0;

  /// How far the logo may shrink with its mark, and the lettering on its
  /// own, before the next step is taken.
  static const _minScaleWithMark = 0.6;
  static const _minScaleWordmarkOnly = 0.45;

  @override
  Widget build(BuildContext context) {
    const wordmark = PetLoopWordmark(
      key: HomeTopBar.brandWordmarkKey,
      height: _wordmarkHeight,
      tone: BrandTone.white,
    );

    return Semantics(
      header: true,
      label: _name,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final room = constraints.maxWidth;
            final showWordmark = room >= wordmark.width * _minScaleWordmarkOnly;
            final showMark =
                !showWordmark ||
                room >= (wordmark.width + _markSize + _gap) * _minScaleWithMark;

            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showMark)
                    const PetLoopMark(
                      key: HomeTopBar.brandMarkKey,
                      size: _markSize,
                      tone: BrandTone.white,
                    ),
                  if (showMark && showWordmark) const SizedBox(width: _gap),
                  if (showWordmark) wordmark,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The part of the coral header that scrolls with the dashboard: the pet
/// selector.
///
/// Square-bottomed: the hero below it paints the rest of the coral band and
/// its rounded bottom edge.
class HomePetRow extends StatelessWidget {
  const HomePetRow({super.key, this.topInset = 0});

  /// Coral space left at the top for the pinned [HomeTopBar], which is
  /// drawn over it.
  final double topInset;

  /// Coral painted above the row, outside its own box. It only shows when
  /// the page is pulled down past its top (the bounce on iOS): without it a
  /// cream gap would open between the pinned bar and this row.
  static const _overscrollCover = 600.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: -_overscrollCover,
          height: _overscrollCover,
          child: ColoredBox(color: AppColors.coral),
        ),
        ColoredBox(
          color: AppColors.coral,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                topInset + 8,
                AppSpacing.screen,
                10,
              ),
              // Full width: the coral band runs edge to edge whatever the
              // number of pets.
              child: SizedBox(
                width: double.infinity,
                child: PetSelector(
                  onAdd: () => openFeature<Object>(context, 'add-pet', ''),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
