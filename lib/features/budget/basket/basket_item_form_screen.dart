import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/unsaved_changes_guard.dart';
import '../../care/widgets/care_widgets.dart';
import '../../health/state/health_providers.dart' show healthClockProvider;
import '../budget_words.dart';
import '../data/budget_models.dart';
import '../state/budget_providers.dart';
import '../widgets/budget_widgets.dart';

/// Opens the form of [item], or of a new product.
Future<void> openBasketItemForm(BuildContext context, {BasketItem? item}) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => BasketItemFormScreen(item: item)));

/// Adds or changes a regular product: its name, pet, kind, package, last
/// price and purchase, and how long a package lasts (worked out from the
/// feeding for food, or the owner's own number).
class BasketItemFormScreen extends ConsumerStatefulWidget {
  const BasketItemFormScreen({super.key, this.item});

  static const nameKey = Key('basket-name');
  static const sizeKey = Key('basket-size');
  static const priceKey = Key('basket-price');
  static const lastsKey = Key('basket-lasts');
  static const ownLastsKey = Key('basket-own-lasts');
  static const saveKey = Key('basket-save');
  static const deleteKey = Key('basket-delete');

  final BasketItem? item;

  @override
  ConsumerState<BasketItemFormScreen> createState() => _BasketItemFormScreenState();
}

class _BasketItemFormScreenState extends ConsumerState<BasketItemFormScreen> {
  final _form = GlobalKey<FormState>();
  late final BasketItem? _item = widget.item;
  late final _name = TextEditingController(text: _item?.name ?? '');
  late final _size = TextEditingController(text: _numberText(_item?.packageSize));
  late final _price = TextEditingController(text: _numberText(_item?.lastPrice));
  late final _lasts = TextEditingController(text: _lastsText());
  late String _petId = _item?.petId ?? ref.read(selectedPetProvider).id;
  late BasketKind _kind = _item?.kind ?? BasketKind.food;
  late BasketUnit _unit = _item?.unit ?? BasketUnit.kg;
  late DateTime? _boughtOn = _item == null ? _today() : _item.lastBoughtOn;
  late bool _inWeeks = _lastsInWeeks(_item?.lastsDays);

  /// Food only: the owner says how long it lasts instead of the feeding.
  late bool _ownLasts = _item?.lastsDays != null;
  bool _saving = false;
  Object? _error;

  /// The fields as the page opened, to tell whether anything changed.
  late final List<Object?> _initial;

  static bool _lastsInWeeks(int? days) => days != null && days >= 14 && days % 7 == 0;

  String _lastsText() {
    final days = _item?.lastsDays;
    if (days == null) return '';
    return (_lastsInWeeks(days) ? days ~/ 7 : days).toString();
  }

  DateTime _today() {
    final now = ref.read(healthClockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  static String _numberText(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  static double? _number(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  List<Object?> _fields() => [
    for (final c in [_name, _size, _price, _lasts]) c.text,
    _petId,
    _kind,
    _unit,
    _boughtOn,
    _inWeeks,
    _ownLasts,
  ];

  bool get _dirty => !_saving && !listEquals(_fields(), _initial);

  /// Food without the owner's own number lasts as long as the feeding says.
  bool get _byFeeding => _kind == BasketKind.food && !_ownLasts;

  @override
  void initState() {
    super.initState();
    _initial = _fields();
    // The run-out worked out from the feeding follows the package size.
    _size.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _size, _price, _lasts]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _boughtOn ?? today,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _boughtOn = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final lasts = _byFeeding ? null : int.tryParse(_lasts.text.trim());
    final item = BasketItem(
      id: _item?.id ?? '',
      petId: _petId,
      name: _name.text.trim(),
      kind: _kind,
      packageSize: _number(_size.text)!,
      unit: _unit,
      lastPrice: _number(_price.text),
      currency: _item?.currency ?? AppConfig.defaultCurrency,
      lastBoughtOn: _boughtOn,
      lastsDays: lasts == null ? null : lasts * (_inWeeks ? 7 : 1),
    );
    try {
      await ref.read(basketProvider.notifier).save(item);
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
    final item = _item!;
    final l10n = context.budgetL10n;
    final common = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProductTitle),
        content: Text(l10n.deleteProductBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(common.commonCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(common.commonDelete)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(basketProvider.notifier).delete(item);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(content: Text(l10n.productDeleted)));
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
    final pets = ref.watch(petsProvider);
    final error = _error;
    final item = _item;
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    Widget chips<T>(List<T> values, T selected, String Function(T) label, ValueChanged<T> onSelected) => Wrap(
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

    // What the feeding says, for food.
    final rate = _kind == BasketKind.food ? ref.watch(feedingRateProvider(_petId)).value : null;
    final grams = _unit.grams(_number(_size.text) ?? 0);
    final byFeedingDays = rate == null || grams == null || grams <= 0 || rate.gramsPerDay <= 0
        ? null
        : (grams / rate.gramsPerDay).floor();

    final lastsField = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            key: BasketItemFormScreen.lastsKey,
            controller: _lasts,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (text) {
              final value = (text ?? '').trim();
              if (value.isEmpty && _kind != BasketKind.food) return null;
              final n = int.tryParse(value);
              return n == null || n < 1 || n > 3650 ? l10n.lastsInvalid : null;
            },
            decoration: InputDecoration(labelText: l10n.lastsAbout),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: chips([false, true], _inWeeks, (weeks) => weeks ? l10n.weeks : l10n.days, (v) => _inWeeks = v),
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
            key: BasketItemFormScreen.nameKey,
            controller: _name,
            maxLength: 80,
            validator: (text) => (text ?? '').trim().isEmpty ? l10n.nameRequired : null,
            decoration: InputDecoration(labelText: l10n.productName, hintText: l10n.productNameHint, counterText: ''),
          ),
          CareSectionLabel(l10n.forLabel),
          chips(
            [for (final p in pets) p.id],
            _petId,
            (id) => pets.firstWhere((p) => p.id == id).name,
            (v) => _petId = v,
          ),
          CareSectionLabel(l10n.kindLabel),
          chips(BasketKind.values, _kind, l10n.kind, (v) => _kind = v),
          CareSectionLabel(l10n.packageSize),
          TextFormField(
            key: BasketItemFormScreen.sizeKey,
            controller: _size,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numbers,
            validator: (text) {
              final value = _number(text ?? '');
              return value == null || value <= 0 || value > 100000 ? l10n.sizeInvalid : null;
            },
            decoration: InputDecoration(labelText: l10n.packageSize),
          ),
          const SizedBox(height: 8),
          chips(BasketUnit.values, _unit, l10n.unit, (v) => _unit = v),
          const SizedBox(height: 12),
          TextFormField(
            key: BasketItemFormScreen.priceKey,
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numbers,
            validator: (text) {
              if ((text ?? '').trim().isEmpty) return null;
              final value = _number(text!);
              return value == null || value < 0 || value > 1000000 ? l10n.amountInvalid : null;
            },
            decoration: InputDecoration(labelText: l10n.lastPrice),
          ),
          CareSectionLabel(l10n.boughtOnLabel),
          CareBox(
            onTap: _pickDate,
            child: Row(
              children: [
                const AppIcon(Icons.calendar_today_rounded, size: 18, color: AppColors.brown),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_boughtOn == null ? l10n.notBoughtYet : format.date(_boughtOn!), style: AppText.body),
                ),
              ],
            ),
          ),
          CareSectionLabel(l10n.lastsLabel),
          if (_kind == BasketKind.food) ...[
            chips(
              [false, true],
              _ownLasts,
              (own) => own ? l10n.lastsOwnChoice : l10n.lastsByFeedingChoice,
              (v) => _ownLasts = v,
            ),
            const SizedBox(height: 8),
            if (_ownLasts)
              KeyedSubtree(key: BasketItemFormScreen.ownLastsKey, child: lastsField)
            else
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Text(
                  byFeedingDays == null
                      ? l10n.lastsNoFeeding
                      : l10n.lastsByFeeding(format.integer(byFeedingDays), format.integer(rate!.gramsPerDay.round())),
                  style: AppText.body,
                ),
              ),
          ] else ...[
            lastsField,
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6, top: 4),
              child: Text(l10n.lastsOptional, style: AppText.secondary),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(budgetErrorText(context, error), style: AppText.body.copyWith(color: AppColors.coralDark)),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            key: BasketItemFormScreen.saveKey,
            label: context.l10n.commonSave,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_name, _size, _price, _lasts]),
      builder: (context, child) => UnsavedChangesGuard(dirty: _dirty, child: child!),
      child: BudgetKeeper(
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoralHeader(
                title: item == null ? l10n.newProduct : l10n.editProduct,
                showBack: true,
                actions: [
                  if (item != null)
                    CoralHeaderAction(
                      key: BasketItemFormScreen.deleteKey,
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
                    24 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
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
