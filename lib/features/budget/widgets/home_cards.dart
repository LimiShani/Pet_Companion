import 'package:flutter/material.dart';
import '../../../presentation/budget_widgets.dart';
import 'spending_card.dart';
import '../../basket/running_low_card.dart';
export 'spending_card.dart';
export '../../basket/running_low_card.dart';

class BudgetHomeCards extends StatelessWidget {
  const BudgetHomeCards({super.key});
  @override
  Widget build(BuildContext context) => const BudgetKeeper(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SpendingCard(), RunningLowCard()],
    ),
  );
}
