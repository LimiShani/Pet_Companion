import '../platform/feature_module.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../access/access_provider.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'petloop_icon.dart';

/// Bottom navigation: Home, Health, Community, Outside, Store. On a right-to-left
/// screen the row mirrors by itself, so Home sits on the right.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.tabs,
  });

  final List<FeatureTab>? tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// The pill behind the selected tab's icon, for tests.
  static const selectedPillKey = Key('nav-selected-pill');

  /// The brand pack's line icons, each in its area's colour (see
  /// [AppArea]): the selected tab's icon sits on a pill of its area's fill,
  /// in ink; the others are stroked in the area's deep variant.
  static const _items = [
    PetLoopGlyph.home,
    PetLoopGlyph.health,
    PetLoopGlyph.community,
    PetLoopGlyph.shop,
  ];
  static const _areas = [
    AppArea.care,
    AppArea.health,
    AppArea.community,
    AppArea.store,
  ];

  /// Home's area: daily care.
  static const homeArea = AppArea.care;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registered = tabs;
    final items = registered == null
        ? _items
        : [PetLoopGlyph.home, for (final tab in registered) tab.glyph];
    final areas = registered == null
        ? _areas
        : [homeArea, for (final tab in registered) tab.area];
    final visible = registered == null
        ? [
            true,
            ref.watch(
              capabilityProvider(
                'health.records.view|health.schedule.view|health.emergency.view',
              ),
            ),
            ref.watch(
              capabilityProvider(
                'community.feed.view|community.chat.view|community.guides.view',
              ),
            ),
            ref.watch(capabilityProvider('store.deals.view')),
          ]
        : [
            true,
            for (final tab in registered)
              ref.watch(capabilityProvider(tab.capability)),
          ];
    final labels = registered == null
        ? [l10n.navHome, l10n.navHealth, l10n.navCommunity, l10n.navStore]
        : [l10n.navHome, for (final tab in registered) tab.label(context)];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.shellRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F5B4636),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // Five tabs share the row: a narrower edge leaves each label
          // the room "Community" needs on a 320 px phone.
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                if (visible[i])
                  Expanded(
                    child: _NavItem(
                      label: labels[i],
                      icon: items[i],
                      area: areas[i],
                      selected: i == currentIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.area,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final PetLoopGlyph icon;
  final AppArea area;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The selected tab's icon on a pill of its area's colour.
                AnimatedContainer(
                  key: selected ? AppBottomNav.selectedPillKey : null,
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 30,
                  decoration: ShapeDecoration(
                    color: selected ? area.disc : Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  alignment: Alignment.center,
                  child: PetLoopIcon(
                    icon,
                    size: 22,
                    color: selected ? AppColors.ink : area.deep,
                  ),
                ),
                const SizedBox(height: 3),
                // Shrinks a little rather than cut a word short when the
                // text is large or the phone narrow.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: AppText.navLabel.copyWith(
                        color: selected ? AppColors.ink : AppColors.brown,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
