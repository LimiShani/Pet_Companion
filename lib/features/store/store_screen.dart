import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

/// Marketplace for bargain pet products. Placeholder until built.
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Store',
      icon: Icons.shopping_bag_rounded,
      message: 'Bargain products for your pets, from food to toys, will be listed here.',
    );
  }
}
