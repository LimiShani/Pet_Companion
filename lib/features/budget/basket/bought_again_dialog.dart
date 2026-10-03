import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../health/state/health_providers.dart' show healthClockProvider;
import '../budget_words.dart';
import '../data/budget_models.dart';
import '../state/budget_providers.dart';

/// "Bought again": asks for the price (last time's, ready to change) and
/// the day (today), then updates the product and records the expense.
/// Says so at the bottom of the screen once it is saved.
Future<void> boughtAgain(BuildContext context, BasketItem item) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final format = AppFormat.of(context);
  final l10n = context.budgetL10n;
  final expense = await showDialog<Expense>(
    context: context,
    useRootNavigator: true,
    builder: (_) => BoughtAgainDialog(item: item),
  );
  if (expense == null) return;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.addedToBudget(format.money(expense.amount, expense.currency)))));
}

class BoughtAgainDialog extends ConsumerStatefulWidget {
  const BoughtAgainDialog({super.key, required this.item});

  static const priceKey = Key('bought-again-price');
  static const saveKey = Key('bought-again-save');

  final BasketItem item;

  @override
  ConsumerState<BoughtAgainDialog> createState() => _BoughtAgainDialogState();
}

class _BoughtAgainDialogState extends ConsumerState<BoughtAgainDialog> {
  final _form = GlobalKey<FormState>();
  late final _price = TextEditingController(text: _priceText(widget.item.lastPrice));
  late DateTime _date = _today();
  bool _saving = false;
  Object? _error;

  DateTime _today() {
    final now = ref.read(healthClockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  static String _priceText(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  static double? _number(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final expense = await ref
          .read(basketProvider.notifier)
          .boughtAgain(widget.item, price: _number(_price.text)!, on: _date);
      if (mounted) Navigator.of(context).pop(expense);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.budgetL10n;
    final format = AppFormat.of(context);
    final error = _error;
    return AlertDialog(
      title: Text(l10n.boughtAgainTitle(widget.item.name)),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: BoughtAgainDialog.priceKey,
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                validator: (text) {
                  final value = _number(text ?? '');
                  return value == null || value < 0 || value > 1000000 ? l10n.amountInvalid : null;
                },
                decoration: InputDecoration(labelText: l10n.lastPrice),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      const AppIcon(Icons.calendar_today_rounded, size: 18, color: AppColors.brown),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${l10n.dateLabel}: ${format.date(_date)}', style: AppText.body)),
                    ],
                  ),
                ),
              ),
              Text(l10n.boughtAgainNote, style: AppText.secondary),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(budgetErrorText(context, error), style: AppText.body.copyWith(color: AppColors.coralDark)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          key: BoughtAgainDialog.saveKey,
          onPressed: _saving ? null : _save,
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}
