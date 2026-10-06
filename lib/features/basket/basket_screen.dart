import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/pet_selector.dart';
import '../../access/feature_gate.dart';
import 'basket_view.dart';

Future<void> openBasket(BuildContext context) async => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => const BasketScreen()));

class BasketScreen extends StatelessWidget {
  const BasketScreen({super.key});
  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'basket.view',
    builder: (_) => Scaffold(
      body: Column(
        children: [
          CoralHeader(
            title: context.budgetL10n.myBasket,
            bottom: const PetSelector(),
          ),
          const Expanded(child: BasketView()),
        ],
      ),
    ),
  );
}
