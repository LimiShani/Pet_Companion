import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/pet_selector.dart';
import '../../auth/widgets/account_sheet.dart';
import '../../health/emergency/emergency.dart';

/// The pinned top bar of the dashboard: menu, branding, the Emergency pill
/// for the selected pet and the account avatar.
///
/// It stays in place while the dashboard scrolls under it, so the emergency
/// actions are always one tap away. The pill and everything it opens belong
/// to the Health feature; Home only places it.
class HomeTopBar extends ConsumerWidget {
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

  static const _menuSize = 44.0;
  static const _avatarSize = 40.0;
  static const _gapBeforePill = 4.0;
  static const _gapAfterPill = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    // A Material (not a plain coloured box) so the ripples of the buttons
    // on it are visible.
    return Material(
      color: AppColors.coral,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.brown,
      elevation: raised ? 6 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(raised ? AppSpacing.shellRadius : 0)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, _paddingTop, AppSpacing.screen, _paddingBottom),
          child: SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded, size: 26),
                  color: AppColors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: _menuSize, height: _menuSize),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // The pill keeps its natural size and the title takes
                      // what is left. Only when the pill alone is wider than
                      // the room between menu and avatar (a tiny phone with
                      // very large text) is the pill scaled down to fit.
                      final pillRoom = math.max(0.0, constraints.maxWidth - _gapBeforePill);
                      return Row(
                        children: [
                          const Expanded(child: _Brand()),
                          const SizedBox(width: _gapBeforePill),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: pillRoom),
                            child: FittedBox(fit: BoxFit.scaleDown, child: EmergencyButton(petId: petId)),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: _gapAfterPill),
                _AccountAvatar(
                  initial: user?.initial ?? '?',
                  onTap: user == null ? null : () => AccountSheet.show(context, user),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paw and "Pet Companion", shrinking to the room the Emergency pill
/// leaves: first the whole title scales down, then the paw is dropped so
/// the words stay readable, and on the narrowest screens only the paw
/// remains.
class _Brand extends StatelessWidget {
  const _Brand();

  static const _name = 'Pet Companion';
  static const _iconSize = 22.0;
  static const _gap = 8.0;

  /// How far the title may shrink with its paw, and on its own, before the
  /// next step is taken.
  static const _minScaleWithIcon = 0.6;
  static const _minScaleTextOnly = 0.45;

  @override
  Widget build(BuildContext context) {
    final style = AppText.appTitle.copyWith(color: AppColors.white);

    return Semantics(
      header: true,
      label: _name,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final painter = TextPainter(
              text: TextSpan(text: _name, style: DefaultTextStyle.of(context).style.merge(style)),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final textWidth = painter.width;
            painter.dispose();

            final room = constraints.maxWidth;
            final showText = room >= textWidth * _minScaleTextOnly;
            final showIcon = !showText || room >= (textWidth + _iconSize + _gap) * _minScaleWithIcon;

            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon) const Icon(Icons.pets_rounded, color: AppColors.white, size: _iconSize),
                  if (showIcon && showText) const SizedBox(width: _gap),
                  if (showText) Text(_name, style: style, maxLines: 1),
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
/// selector and the pet count.
///
/// Square-bottomed: the hero below it paints the rest of the coral band and
/// its rounded bottom edge.
class HomePetRow extends ConsumerWidget {
  const HomePetRow({super.key, this.topInset = 0});

  /// Coral space left at the top for the pinned [HomeTopBar], which is
  /// drawn over it.
  final double topInset;

  /// Coral painted above the row, outside its own box. It only shows when
  /// the page is pulled down past its top (the bounce on iOS): without it a
  /// cream gap would open between the pinned bar and this row.
  static const _overscrollCover = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(petsProvider.select((pets) => pets.length));

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
              padding: EdgeInsets.fromLTRB(AppSpacing.screen, topInset + 8, AppSpacing.screen, 10),
              child: Row(
                children: [
                  Expanded(child: PetSelector(onAdd: () {})),
                  const SizedBox(width: 8),
                  Text(
                    '$count ${count == 1 ? 'pet' : 'pets'}',
                    style: AppText.label
                        .copyWith(color: AppColors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.initial, required this.onTap});

  final String initial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Account',
      child: Material(
        color: AppColors.yellow,
        shape: CircleBorder(side: BorderSide(color: AppColors.white.withValues(alpha: 0.85), width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: HomeTopBar._avatarSize,
            height: HomeTopBar._avatarSize,
            child: Center(
              child: Text(initial, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
          ),
        ),
      ),
    );
  }
}
