import '../platform/feature_module.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../access/access_provider.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'petloop_icon.dart';

/// Bottom navigation: Home, Health, Community, Store. On a right-to-left
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

  /// The brand pack's line icons; the selected tab is told apart by its
  /// yellow pill and coral colour.
  static const _items = [
    PetLoopGlyph.home,
    PetLoopGlyph.health,
    PetLoopGlyph.community,
    PetLoopGlyph.shop,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registered = tabs;
    final items = registered == null
        ? _items
        : [PetLoopGlyph.home, for (final tab in registered) tab.glyph];
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
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                if (visible[i])
                  Expanded(
                    child: _NavItem(
                      label: labels[i],
                      icon: items[i],
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
    required this.selected,
    required this.onTap,
  });

  final String label;
  final PetLoopGlyph icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.yellow : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PetLoopIcon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.coral : AppColors.brown,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.navLabel.copyWith(
                    color: selected ? AppColors.ink : AppColors.brown,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
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
