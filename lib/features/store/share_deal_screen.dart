import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/primary_button.dart';
import 'data/deal.dart';
import 'data/link_opener.dart';
import 'state/store_providers.dart';
import 'store_format.dart';
import 'store_strings.dart';

/// Checks for the "Share a deal" form, answering in the language of the
/// strings they are given: `DealValidators(context.storeL10n).title`. Each
/// returns `null` when the value is valid.
class DealValidators {
  const DealValidators(this._l10n);

  final StoreL10n _l10n;

  static const minTitleLength = 3;

  /// A typed price, or `null` when it is not a number. Accepts a comma as
  /// the decimal separator and keeps two decimals.
  static double? parsePrice(String? text) => _parse(text, decimals: 2);

  /// A typed package amount ("2.5", "1020"), or `null` when it is not a
  /// number. Keeps three decimals.
  static double? parseAmount(String? text) => _parse(text, decimals: 3);

  static double? _parse(String? text, {required int decimals}) {
    final value = double.tryParse((text ?? '').trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite) return null;
    final scale = decimals == 2 ? 100 : 1000;
    return (value * scale).round() / scale;
  }

  String? title(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return _l10n.validTitleRequired;
    if (v.length < minTitleLength) return _l10n.validTitleTooShort(minTitleLength);
    return null;
  }

  String? seller(String? value) => (value?.trim() ?? '').isEmpty ? _l10n.validSellerRequired : null;

  String? category(DealCategory? value) => value == null ? _l10n.validCategoryRequired : null;

  /// The old price: a number above zero.
  String? originalPrice(String? value) {
    if ((value?.trim() ?? '').isEmpty) return _l10n.validOriginalPriceRequired;
    final price = parsePrice(value);
    if (price == null) return _l10n.validNotANumber;
    if (price <= 0) return _l10n.validPriceAboveZero;
    return null;
  }

  /// The deal price: a number above zero and below the old price typed in
  /// [originalText].
  String? price(String? value, String originalText) {
    if ((value?.trim() ?? '').isEmpty) return _l10n.validPriceRequired;
    final price = parsePrice(value);
    if (price == null) return _l10n.validNotANumber;
    if (price <= 0) return _l10n.validPriceAboveZero;
    final original = parsePrice(originalText);
    if (original != null && price >= original) return _l10n.validPriceBelowOriginal;
    return null;
  }

  String? link(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return _l10n.validLinkRequired;
    final uri = safeDealLink(v);
    if (uri == null || !uri.host.contains('.')) return _l10n.validLinkNotHttps(httpsPrefix);
    return null;
  }

  /// The package amount is optional; when typed it is a number above zero.
  String? packageAmount(String? value) {
    if ((value?.trim() ?? '').isEmpty) return null;
    final amount = parseAmount(value);
    return amount == null || amount <= 0 ? _l10n.validPackageAmount : null;
  }

  /// A typed package amount needs a unit. A unit on its own is ignored.
  String? packageUnit(PackageUnit? unit, String amountText) =>
      unit == null && amountText.trim().isNotEmpty ? _l10n.validPackageUnit : null;

  /// What a paid delivery costs: a number above zero.
  String? deliveryCost(String? value) {
    if ((value?.trim() ?? '').isEmpty) return _l10n.validDeliveryCostRequired;
    final cost = parsePrice(value);
    return cost == null || cost <= 0 ? _l10n.validDeliveryCostInvalid : null;
  }
}

/// What the sharer knows about delivery.
enum _Delivery { notSure, free, paid }

/// Full-screen form for sharing a bargain with other pet owners. Pops with
/// the new [Deal] once it is stored.
class ShareDealScreen extends ConsumerStatefulWidget {
  const ShareDealScreen({super.key});

  @override
  ConsumerState<ShareDealScreen> createState() => _ShareDealScreenState();
}

class _ShareDealScreenState extends ConsumerState<ShareDealScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _original = TextEditingController();
  final _packageAmount = TextEditingController();
  final _deliveryCost = TextEditingController();
  final _seller = TextEditingController();
  final _link = TextEditingController();
  final _description = TextEditingController();
  DealCategory? _category;
  PackageUnit? _packageUnit;
  _Delivery _delivery = _Delivery.notSure;
  DateTime? _endDate;
  bool _sending = false;

  /// Why the last attempt to share failed; shown above the button.
  Object? _error;

  /// The animals the deal is for; empty means every pet. Starts on the kind
  /// of the pet being shopped for.
  late final Set<PetSpecies> _species = _initialSpecies();

  // Quiet until the first attempt to send, then problems update as they
  // are fixed.
  AutovalidateMode _validation = AutovalidateMode.disabled;

  Set<PetSpecies> _initialSpecies() {
    final pet = ref.read(selectedPetProvider);
    return pet.id.isEmpty ? {} : {pet.species};
  }

  @override
  void dispose() {
    for (final c in [_title, _price, _original, _packageAmount, _deliveryCost, _seller, _link, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickEndDate() async {
    final now = ref.read(storeClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      currentDate: today,
      helpText: context.storeL10n.lastDayOfDeal,
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  void _toggleSpecies(PetSpecies? kind) {
    setState(() {
      if (kind == null) {
        _species.clear();
      } else if (!_species.remove(kind)) {
        _species.add(kind);
      }
    });
  }

  /// The package as typed, or `null` when it is left out or not valid yet.
  PackageSize? get _package {
    final amount = DealValidators.parseAmount(_packageAmount.text);
    final unit = _packageUnit;
    return amount == null || amount <= 0 || unit == null ? null : PackageSize(amount, unit);
  }

  /// The delivery cost as chosen: `null` for "not sure", zero for free.
  double? get _deliveryAmount => switch (_delivery) {
        _Delivery.notSure => null,
        _Delivery.free => 0,
        _Delivery.paid => DealValidators.parsePrice(_deliveryCost.text),
      };

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_form.currentState!.validate()) {
      setState(() => _validation = AutovalidateMode.onUserInteraction);
      return;
    }

    final end = _endDate;
    final draft = DealDraft(
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category!,
      price: DealValidators.parsePrice(_price.text)!,
      originalPrice: DealValidators.parsePrice(_original.text)!,
      currency: kStoreDefaultCurrency,
      sellerName: _seller.text.trim(),
      link: _link.text.trim(),
      // The deal runs until the end of its last day.
      expiresAt: end == null ? null : DateTime(end.year, end.month, end.day, 23, 59, 59),
      package: _package,
      deliveryCost: _deliveryAmount,
      species: {..._species},
    );

    setState(() => _sending = true);
    try {
      final deal = await ref.read(dealsProvider.notifier).share(draft);
      if (mounted) Navigator.of(context).pop(deal);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    final format = StoreFormat.of(context);
    final valid = DealValidators(l10n);
    final symbol = format.currencySymbol(kStoreDefaultCurrency);
    final today = ref.watch(storeClockProvider)();
    final error = _error;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.shareADeal, showBack: true),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 16, AppSpacing.screen, 24),
              child: SafeArea(
                top: false,
                child: Form(
                  key: _form,
                  autovalidateMode: _validation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.shareIntro, style: AppText.body.copyWith(color: AppColors.brown)),
                      const SizedBox(height: 14),
                      _Labeled(
                        label: l10n.fieldTitle,
                        child: TextFormField(
                          key: const Key('share-title'),
                          controller: _title,
                          validator: valid.title,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: [LengthLimitingTextInputFormatter(120)],
                          decoration: InputDecoration(hintText: l10n.fieldTitleHint, errorMaxLines: 3),
                        ),
                      ),
                      _Labeled(
                        label: l10n.fieldCategory,
                        child: DropdownButtonFormField<DealCategory>(
                          key: const Key('share-category'),
                          initialValue: _category,
                          isExpanded: true,
                          validator: valid.category,
                          onChanged: (value) => setState(() => _category = value),
                          icon: const Icon(Icons.expand_more_rounded, color: AppColors.brown),
                          dropdownColor: AppColors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                          style: _fieldStyle,
                          decoration: const InputDecoration(errorMaxLines: 3),
                          hint: _DropdownHint(l10n.fieldCategoryHint),
                          items: [
                            for (final category in DealCategory.values)
                              DropdownMenuItem(
                                value: category,
                                child: Text(l10n.category(category), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                      _Labeled(
                        label: l10n.fieldAnimals,
                        help: l10n.fieldAnimalsHelp,
                        child: _AnimalChips(selected: _species, onToggle: _toggleSpecies),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Labeled(
                              label: l10n.fieldPriceNow(symbol),
                              child: TextFormField(
                                key: const Key('share-price'),
                                controller: _price,
                                validator: (value) => valid.price(value, _original.text),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(hintText: '0', errorMaxLines: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Labeled(
                              label: l10n.fieldPriceBefore(symbol),
                              child: TextFormField(
                                key: const Key('share-original-price'),
                                controller: _original,
                                validator: valid.originalPrice,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(hintText: '0', errorMaxLines: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _Hint(
                        listenTo: [_price, _original],
                        text: () {
                          final now = DealValidators.parsePrice(_price.text);
                          final before = DealValidators.parsePrice(_original.text);
                          if (now == null || before == null || now <= 0 || now >= before) return null;
                          return l10n.hintPercentOff(((1 - now / before) * 100).round());
                        },
                      ),
                      _Labeled(
                        label: l10n.fieldPackageSize,
                        help: l10n.fieldPackageHelp,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: const Key('share-package-amount'),
                                controller: _packageAmount,
                                validator: valid.packageAmount,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                // The unit's "choose a unit" problem depends on this field.
                                onChanged: (_) {
                                  if (_validation != AutovalidateMode.disabled) _form.currentState?.validate();
                                },
                                decoration: InputDecoration(hintText: l10n.fieldPackageAmountHint, errorMaxLines: 4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<PackageUnit>(
                                key: const Key('share-package-unit'),
                                initialValue: _packageUnit,
                                isExpanded: true,
                                validator: (unit) => valid.packageUnit(unit, _packageAmount.text),
                                onChanged: (value) => setState(() => _packageUnit = value),
                                icon: const Icon(Icons.expand_more_rounded, color: AppColors.brown),
                                dropdownColor: AppColors.white,
                                borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                                style: _fieldStyle,
                                decoration: const InputDecoration(errorMaxLines: 4),
                                hint: _DropdownHint(l10n.fieldPackageUnitHint),
                                items: [
                                  for (final unit in PackageUnit.values)
                                    DropdownMenuItem(
                                      value: unit,
                                      child: Text(l10n.unit(unit), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Hint(
                        key: const Key('share-unit-price-hint'),
                        listenTo: [_price, _packageAmount],
                        text: () {
                          final price = DealValidators.parsePrice(_price.text);
                          final size = _package;
                          if (price == null || price <= 0 || size == null) return null;
                          final unitPrice = UnitPrice(price / size.inBaseUnits, size.unit.kind);
                          return l10n.hintUnitPrice(format.unitPrice(unitPrice, kStoreDefaultCurrency));
                        },
                      ),
                      _Labeled(
                        label: l10n.fieldDelivery,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final (option, label) in [
                                  (_Delivery.notSure, l10n.deliveryNotSure),
                                  (_Delivery.free, l10n.deliveryFree),
                                  (_Delivery.paid, l10n.deliveryPaid),
                                ])
                                  ChoiceChip(
                                    key: Key('share-delivery-${option.name}'),
                                    label: Text(label),
                                    selected: _delivery == option,
                                    showCheckmark: false,
                                    onSelected: (_) => setState(() => _delivery = option),
                                  ),
                              ],
                            ),
                            if (_delivery == _Delivery.paid) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const Key('share-delivery-cost'),
                                controller: _deliveryCost,
                                validator: valid.deliveryCost,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(hintText: l10n.fieldDeliveryCost(symbol), errorMaxLines: 3),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _Hint(
                        key: const Key('share-final-price-hint'),
                        listenTo: [_price, _deliveryCost],
                        text: () {
                          final price = DealValidators.parsePrice(_price.text);
                          final delivery = _deliveryAmount;
                          if (price == null || price <= 0 || delivery == null || delivery < 0) return null;
                          return l10n.hintFinalPrice(format.money(price + delivery, kStoreDefaultCurrency));
                        },
                      ),
                      _Labeled(
                        label: l10n.sellerLabel,
                        child: TextFormField(
                          key: const Key('share-seller'),
                          controller: _seller,
                          validator: valid.seller,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [LengthLimitingTextInputFormatter(80)],
                          decoration: InputDecoration(hintText: l10n.fieldSellerHint, errorMaxLines: 3),
                        ),
                      ),
                      _Labeled(
                        label: l10n.fieldLink,
                        child: TextFormField(
                          key: const Key('share-link'),
                          controller: _link,
                          validator: valid.link,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          // A link reads left to right in every language,
                          // and so does the hint that shows how it starts.
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            hintText: httpsPrefix,
                            hintTextDirection: TextDirection.ltr,
                            errorMaxLines: 3,
                          ),
                        ),
                      ),
                      _Labeled(
                        label: l10n.fieldDescription,
                        child: TextFormField(
                          key: const Key('share-description'),
                          controller: _description,
                          minLines: 3,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                          decoration: InputDecoration(hintText: l10n.fieldDescriptionHint),
                        ),
                      ),
                      _Labeled(
                        label: l10n.fieldEndDate,
                        child: _EndDateField(
                          date: _endDate,
                          onPick: _pickEndDate,
                          onClear: () => setState(() => _endDate = null),
                        ),
                      ),
                      if (error != null) ...[
                        Text(
                          storeErrorText(context, error),
                          style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        l10n.checkedTodayNote(format.date(today)),
                        style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(label: l10n.shareDealButton, onPressed: _submit, loading: _sending),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static final _fieldStyle = AppText.body.copyWith(fontSize: 16, color: AppColors.ink);
}

/// A small brown label above a form field, as on the auth screens, with an
/// optional line of help under it.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child, this.help});

  final String label;
  final Widget child;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 6),
            child: Text(label, style: AppText.label.copyWith(color: AppColors.brown)),
          ),
          child,
          if (help != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 5, end: 8),
              child: Text(help!, style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// The greyed text of a dropdown that has nothing chosen yet.
class _DropdownHint extends StatelessWidget {
  const _DropdownHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.body.copyWith(fontSize: 16, color: AppColors.brown.withValues(alpha: 0.55)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// "All pets" and one chip per kind of animal. Choosing "All pets" clears
/// the kinds; with no kind chosen the deal is for all pets.
class _AnimalChips extends StatelessWidget {
  const _AnimalChips({required this.selected, required this.onToggle});

  final Set<PetSpecies> selected;

  /// Called with a kind of animal, or with `null` for "All pets".
  final ValueChanged<PetSpecies?> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilterChip(
          key: const Key('share-animals-all'),
          label: Text(l10n.allPets),
          selected: selected.isEmpty,
          onSelected: (_) => onToggle(null),
        ),
        for (final kind in PetSpecies.values)
          FilterChip(
            key: Key('share-animals-${kind.name}'),
            label: Text(l10n.animals(kind)),
            selected: selected.contains(kind),
            onSelected: (_) => onToggle(kind),
          ),
      ],
    );
  }
}

/// A sage pill with a worked-out figure ("That is 39% off"), shown as soon
/// as what it depends on makes sense. [text] returns `null` to hide it.
class _Hint extends StatelessWidget {
  const _Hint({super.key, required this.listenTo, required this.text});

  final List<Listenable> listenTo;
  final String? Function() text;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(listenTo),
      builder: (context, _) {
        final value = text();
        if (value == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(999)),
              child: Text(value, style: AppText.secondary.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
        );
      },
    );
  }
}

/// Looks like a text field; opens the calendar. Shows the chosen last day
/// with a button to remove it.
class _EndDateField extends StatelessWidget {
  const _EndDateField({required this.date, required this.onPick, required this.onClear});

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    final picked = date;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('share-end-date'),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 18, end: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    picked == null ? l10n.addEndDate : l10n.endsDate(StoreFormat.of(context).date(picked)),
                    style: AppText.body.copyWith(
                      fontSize: 16,
                      color: picked == null ? AppColors.brown : AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (picked == null)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.event_rounded, color: AppColors.brown),
                  )
                else
                  IconButton(
                    tooltip: l10n.removeEndDate,
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, color: AppColors.brown),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
