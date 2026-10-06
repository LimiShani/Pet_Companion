import '../../access/feature_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/unsaved_changes_guard.dart';
import '../../presentation/care_widgets.dart';
import '../../services/pet_records/state/health_providers.dart'
    show healthClockProvider;
import '../../presentation/budget_words.dart';
import '../../services/budget/data/budget_models.dart';
import '../../services/budget/state/budget_providers.dart';
import '../../presentation/budget_widgets.dart';

/// Opens the form of [expense], or of a new expense for [petId] (`null`:
/// the whole home).
Future<void> openExpenseForm(
  BuildContext context, {
  Expense? expense,
  String? petId,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    builder: (_) => ExpenseFormScreen(expense: expense, petId: petId),
  ),
);

/// Adds or changes an expense: the amount, the category, the pet (or the
/// whole home), the date, a note and how often it is paid. A stored
/// expense can be deleted here, and a recurring one stopped.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expense, this.petId});

  static const amountKey = Key('expense-amount');
  static const noteKey = Key('expense-note');
  static const dateKey = Key('expense-date');
  static const saveKey = Key('expense-save');
  static const deleteKey = Key('expense-delete');
  static const stopKey = Key('expense-stop');

  final Expense? expense;
  final String? petId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Expense? _expense = widget.expense;
  late final _amount = TextEditingController(
    text: _expense == null ? '' : _numberText(_expense.amount),
  );
  late final _note = TextEditingController(text: _expense?.note ?? '');
  late ExpenseCategory _category = _expense?.category ?? ExpenseCategory.food;
  late String? _petId = _expense == null ? widget.petId : _expense.petId;
  late DateTime _date = _expense?.spentOn ?? _today();
  late ExpenseFrequency _frequency =
      _expense?.frequency ?? ExpenseFrequency.once;
  late DateTime? _endedOn = _expense?.endedOn;
  bool _saving = false;
  Object? _error;

  /// The fields as the page opened, to tell whether anything changed.
  late final List<Object?> _initial;

  DateTime _today() {
    final now = ref.read(healthClockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  static String _numberText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  static double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  List<Object?> _fields() => [
    _amount.text,
    _note.text,
    _category,
    _petId,
    _date,
    _frequency,
    _endedOn,
  ];

  bool get _dirty => !_saving && !listEquals(_fields(), _initial);

  @override
  void initState() {
    super.initState();
    _initial = _fields();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final old = _expense;
    final expense = Expense(
      id: old?.id ?? '',
      petId: _petId,
      amount: _number(_amount.text)!,
      currency: old?.currency ?? AppConfig.defaultCurrency,
      category: _category,
      spentOn: _date,
      note: _note.text.trim(),
      frequency: _frequency,
      source: old?.source ?? ExpenseSource.manual,
      basketItemId: old?.basketItemId,
      endedOn: _frequency == ExpenseFrequency.once ? null : _endedOn,
    );
    try {
      await ref.read(expensesProvider.notifier).save(expense);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _delete() async {
    final expense = _expense!;
    final l10n = context.budgetL10n;
    final common = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteExpenseTitle),
        content: Text(
          expense.isRecurring
              ? l10n.deleteRecurringBody
              : l10n.deleteExpenseBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(common.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(common.commonDelete),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(expensesProvider.notifier).delete(expense.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(content: Text(l10n.expenseDeleted)));
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
  Widget build(BuildContext context) => FeatureGate(
    capability: 'budget.edit',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.budgetL10n;
    final format = AppFormat.of(context);
    final pets = ref.watch(petsProvider);
    final error = _error;
    final expense = _expense;

    Widget chips<T>(
      List<T> values,
      T selected,
      String Function(T) label,
      ValueChanged<T> onSelected,
    ) => Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: value == selected,
            showCheckmark: false,
            selectedColor: AppColors.sage,
            onSelected: (_) => setState(() => onSelected(value)),
          ),
      ],
    );

    final form = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextFormField(
            key: ExpenseFormScreen.amountKey,
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            validator: (text) {
              final value = _number(text ?? '');
              return value == null || value <= 0 || value > 1000000
                  ? l10n.amountInvalid
                  : null;
            },
            decoration: InputDecoration(
              labelText: l10n.amountLabel,
              suffixText: NumberFormat.simpleCurrency(
                name: _expense?.currency ?? AppConfig.defaultCurrency,
              ).currencySymbol,
            ),
          ),
          CareSectionLabel(l10n.categoryLabel),
          chips(
            ExpenseCategory.values,
            _category,
            l10n.category,
            (v) => _category = v,
          ),
          CareSectionLabel(l10n.forLabel),
          chips<String?>([null, for (final p in pets) p.id], _petId, (id) {
            if (id == null) return l10n.wholeHome;
            return pets.firstWhere((p) => p.id == id).name;
          }, (v) => _petId = v),
          CareSectionLabel(l10n.dateLabel),
          CareBox(
            key: ExpenseFormScreen.dateKey,
            onTap: _pickDate,
            child: Row(
              children: [
                const AppIcon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: AppColors.brown,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(format.date(_date), style: AppText.body)),
              ],
            ),
          ),
          TextFormField(
            key: ExpenseFormScreen.noteKey,
            controller: _note,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: l10n.noteLabel,
              hintText: l10n.noteHint,
              counterText: '',
            ),
          ),
          CareSectionLabel(l10n.howOften),
          chips(
            ExpenseFrequency.values,
            _frequency,
            l10n.frequency,
            (v) => _frequency = v,
          ),
          if (_frequency != ExpenseFrequency.once)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6, top: 6),
              child: Text(
                _frequency == ExpenseFrequency.monthly
                    ? l10n.monthlyNote
                    : l10n.yearlyNote,
                style: AppText.secondary,
              ),
            ),
          if (expense != null &&
              !expense.isNew &&
              _frequency != ExpenseFrequency.once) ...[
            const SizedBox(height: 10),
            if (_endedOn == null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: ExpenseFormScreen.stopKey,
                  onPressed: () => setState(() {
                    // Not before the first payment.
                    final today = _today();
                    _endedOn = today.isBefore(_date) ? _date : today;
                  }),
                  icon: const AppIcon(Icons.stop_circle_outlined, size: 18),
                  label: Text(l10n.stopRepeating),
                ),
              )
            else
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    l10n.stoppedOn(format.date(_endedOn!)),
                    style: AppText.body,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _endedOn = null),
                    child: Text(l10n.keepRepeating),
                  ),
                ],
              ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              budgetErrorText(context, error),
              style: AppText.body.copyWith(color: AppColors.coralDark),
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            key: ExpenseFormScreen.saveKey,
            label: context.l10n.commonSave,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_amount, _note]),
      builder: (context, child) =>
          UnsavedChangesGuard(dirty: _dirty, child: child!),
      child: BudgetKeeper(
        page: true,
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoralHeader(
                title: expense == null ? l10n.newExpense : l10n.editExpense,
                showBack: true,
                actions: [
                  if (expense != null)
                    CoralHeaderAction(
                      key: ExpenseFormScreen.deleteKey,
                      icon: Icons.delete_outline_rounded,
                      tooltip: context.l10n.commonDelete,
                      onPressed: _saving ? null : _delete,
                    ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.screen,
                    8,
                    AppSpacing.screen,
                    24 +
                        MediaQuery.viewInsetsOf(context).bottom +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  child: form,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
