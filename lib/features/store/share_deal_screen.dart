import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/primary_button.dart';
import 'data/deal.dart';
import 'data/link_opener.dart';
import 'state/store_providers.dart';
import 'store_format.dart';

/// Checks for the "Share a deal" form. Each returns `null` when valid.
abstract final class DealValidators {
  /// A typed price, or `null` when it is not a number. Accepts a comma as
  /// the decimal separator and keeps two decimals.
  static double? parsePrice(String? text) {
    final value = double.tryParse((text ?? '').trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite) return null;
    return (value * 100).round() / 100;
  }

  static String? title(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Give the deal a title.';
    if (v.length < 3) return 'Use at least 3 characters.';
    return null;
  }

  static String? seller(String? value) => (value?.trim() ?? '').isEmpty ? 'Who is selling it?' : null;

  static String? category(DealCategory? value) => value == null ? 'Pick a category.' : null;

  /// The old price: a number above zero.
  static String? originalPrice(String? value) {
    if ((value?.trim() ?? '').isEmpty) return 'Enter the price before the discount.';
    final price = parsePrice(value);
    if (price == null) return 'Enter a number, like 49.90.';
    if (price <= 0) return 'The price must be above zero.';
    return null;
  }

  /// The deal price: a number above zero and below the old price typed in
  /// [originalText].
  static String? price(String? value, String originalText) {
    if ((value?.trim() ?? '').isEmpty) return 'Enter the price now.';
    final price = parsePrice(value);
    if (price == null) return 'Enter a number, like 49.90.';
    if (price <= 0) return 'The price must be above zero.';
    final original = parsePrice(originalText);
    if (original != null && price >= original) return 'The deal price must be below the original price.';
    return null;
  }

  static String? link(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Paste the link to the offer.';
    final uri = safeDealLink(v);
    if (uri == null || !uri.host.contains('.')) return 'Use a full link that starts with https://';
    return null;
  }
}

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
  final _seller = TextEditingController();
  final _link = TextEditingController();
  final _description = TextEditingController();
  DealCategory? _category;
  DateTime? _endDate;
  bool _sending = false;
  String? _error;

  // Quiet until the first attempt to send, then problems update as they
  // are fixed.
  AutovalidateMode _validation = AutovalidateMode.disabled;

  static final _symbol = NumberFormat.simpleCurrency(name: kStoreDefaultCurrency).currencySymbol;

  @override
  void dispose() {
    for (final c in [_title, _price, _original, _seller, _link, _description]) {
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
      helpText: 'Last day of the deal',
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

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
    );

    setState(() => _sending = true);
    try {
      final deal = await ref.read(dealsProvider.notifier).share(draft);
      if (mounted) Navigator.of(context).pop(deal);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = storeErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CoralHeader(title: 'Share a deal', showBack: true),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 24),
              child: SafeArea(
                top: false,
                child: Form(
                  key: _form,
                  autovalidateMode: _validation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Found a bargain? Tell other pet owners where to get it.',
                        style: AppText.body.copyWith(color: AppColors.brown),
                      ),
                      const SizedBox(height: 14),
                      _Labeled(
                        label: 'Title',
                        child: TextFormField(
                          key: const Key('share-title'),
                          controller: _title,
                          validator: DealValidators.title,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: [LengthLimitingTextInputFormatter(120)],
                          decoration: const InputDecoration(hintText: 'What is on offer?', errorMaxLines: 3),
                        ),
                      ),
                      _Labeled(
                        label: 'Category',
                        child: DropdownButtonFormField<DealCategory>(
                          key: const Key('share-category'),
                          initialValue: _category,
                          isExpanded: true,
                          validator: DealValidators.category,
                          onChanged: (value) => setState(() => _category = value),
                          icon: const Icon(Icons.expand_more_rounded, color: AppColors.brown),
                          dropdownColor: AppColors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                          style: _fieldStyle,
                          decoration: const InputDecoration(errorMaxLines: 3),
                          hint: Text(
                            'Choose a category',
                            style: _fieldStyle.copyWith(color: AppColors.brown.withValues(alpha: 0.55)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          items: [
                            for (final category in DealCategory.values)
                              DropdownMenuItem(
                                value: category,
                                child: Text(category.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Labeled(
                              label: 'Price now ($_symbol)',
                              child: TextFormField(
                                key: const Key('share-price'),
                                controller: _price,
                                validator: (value) => DealValidators.price(value, _original.text),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(hintText: '0', errorMaxLines: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Labeled(
                              label: 'Price before ($_symbol)',
                              child: TextFormField(
                                key: const Key('share-original-price'),
                                controller: _original,
                                validator: DealValidators.originalPrice,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(hintText: '0', errorMaxLines: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _DiscountHint(price: _price, original: _original),
                      _Labeled(
                        label: 'Seller',
                        child: TextFormField(
                          key: const Key('share-seller'),
                          controller: _seller,
                          validator: DealValidators.seller,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [LengthLimitingTextInputFormatter(80)],
                          decoration: const InputDecoration(hintText: 'The shop or website', errorMaxLines: 3),
                        ),
                      ),
                      _Labeled(
                        label: 'Link to the offer',
                        child: TextFormField(
                          key: const Key('share-link'),
                          controller: _link,
                          validator: DealValidators.link,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(hintText: 'https://', errorMaxLines: 3),
                        ),
                      ),
                      _Labeled(
                        label: 'Description (optional)',
                        child: TextFormField(
                          key: const Key('share-description'),
                          controller: _description,
                          minLines: 3,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                          decoration: const InputDecoration(hintText: 'Size, flavour, what is included...'),
                        ),
                      ),
                      _Labeled(
                        label: 'End date (optional)',
                        child: _EndDateField(
                          date: _endDate,
                          onPick: _pickEndDate,
                          onClear: () => setState(() => _endDate = null),
                        ),
                      ),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 6),
                      PrimaryButton(label: 'Share deal', onPressed: _submit, loading: _sending),
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

/// A small brown label above a form field, as on the auth screens.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: Text(label, style: AppText.label.copyWith(color: AppColors.brown)),
          ),
          child,
        ],
      ),
    );
  }
}

/// "That is 39% off", shown as soon as both prices make a real discount.
class _DiscountHint extends StatelessWidget {
  const _DiscountHint({required this.price, required this.original});

  final TextEditingController price;
  final TextEditingController original;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([price, original]),
      builder: (context, _) {
        final now = DealValidators.parsePrice(price.text);
        final before = DealValidators.parsePrice(original.text);
        if (now == null || before == null || now <= 0 || now >= before) return const SizedBox.shrink();
        final percent = ((1 - now / before) * 100).round();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(999)),
              child: Text(
                'That is $percent% off',
                style: AppText.secondary.copyWith(fontWeight: FontWeight.w800),
              ),
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
    final picked = date;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('share-end-date'),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    picked == null ? 'Add an end date' : 'Ends ${StoreFormat.date(picked)}',
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
                    tooltip: 'Remove the end date',
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
