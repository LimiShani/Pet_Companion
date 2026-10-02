import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'petloop_icon.dart';

/// Bottom navigation: Home, Health, Community, Store. On a right-to-left
/// screen the row mirrors by itself, so Home sits on the right.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// The brand pack's line icons; the selected tab is told apart by its
  /// yellow pill and coral colour.
  static const _items = [PetLoopGlyph.home, PetLoopGlyph.health, PetLoopGlyph.community, PetLoopGlyph.shop];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // In the order of [_items].
    final labels = [l10n.navHome, l10n.navHealth, l10n.navCommunity, l10n.navStore];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.shellRadius)),
        boxShadow: [BoxShadow(color: Color(0x1F5B4636), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    label: labels[i],
                    icon: _items[i],
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
  const _NavItem({required this.label, required this.icon, required this.selected, required this.onTap});

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
                PetLoopIcon(icon, size: 22, color: selected ? AppColors.coral : AppColors.brown),
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
