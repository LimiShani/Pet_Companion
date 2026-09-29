import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Bottom navigation: Home, Health, Community, Store.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    (label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    (label: 'Health', icon: Icons.monitor_heart_outlined, activeIcon: Icons.monitor_heart_rounded),
    (label: 'Community', icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded),
    (label: 'Store', icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.shellRadius)),
        boxShadow: [BoxShadow(color: Color(0x1F75562E), blurRadius: 20, offset: Offset(0, -6))],
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
                    label: _items[i].label,
                    icon: i == currentIndex ? _items[i].activeIcon : _items[i].icon,
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
  final IconData icon;
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
                Icon(icon, size: 22, color: selected ? AppColors.coral : AppColors.brown),
                const SizedBox(height: 3),
                Text(
                  label,
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
