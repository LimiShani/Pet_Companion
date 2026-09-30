import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../data/file_services.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../health_strings.dart';
import '../share/lost_card_renderer.dart';
import '../state/health_providers.dart';
import '../state/lost_card.dart';
import '../widgets/health_widgets.dart';
import 'lost_card_view.dart';

/// Opens the "my pet is lost" page of [petId] over the whole app. Nothing
/// opens for an unknown pet id.
Future<void> openLostPetCard(BuildContext context, String petId) {
  for (final pet in ProviderScope.containerOf(context, listen: false).read(petsProvider)) {
    if (pet.id == petId) return pushHealthPage<void>(context, LostPetCardScreen(pet: pet));
  }
  assert(false, 'openLostPetCard: no pet with id "$petId" in petsProvider');
  return Future.value();
}

/// The button that leads to the lost card from the emergency sheet and the
/// Emergency card.
class LostPetButton extends StatelessWidget {
  const LostPetButton({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('open-lost-card'),
      onPressed: () => openLostPetCard(context, pet.id),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
      icon: const Icon(Icons.travel_explore_rounded),
      label: Text(context.healthL10n.petIsLost(pet.name)),
    );
  }
}

/// One page for a lost pet: what goes on the card, the card as it will
/// look, and the owner's confirmation of the phone number. It produces a
/// picture (or a printable PDF) for the phone's share sheet. The app posts
/// nothing anywhere, and the card never carries a saved address, the
/// microchip number or the vet.
class LostPetCardScreen extends ConsumerStatefulWidget {
  const LostPetCardScreen({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<LostPetCardScreen> createState() => _LostPetCardScreenState();
}

class _LostPetCardScreenState extends ConsumerState<LostPetCardScreen> {
  final _form = GlobalKey<FormState>();
  final _cardKey = GlobalKey();
  final _description = TextEditingController();
  final _area = TextEditingController();
  final _phone = TextEditingController();
  final _extra = TextEditingController();
  var _language = LostCardLanguage.hebrew;
  late DateTime _lastSeen;

  /// The pet's own photo, once it is found.
  ImageProvider? _profilePhoto;

  /// A photo chosen just for this card.
  ImageProvider? _chosenPhoto;

  /// The phone number the owner agreed to show; the agreement ends the
  /// moment the number is changed.
  String? _confirmedPhone;
  bool _filled = false;
  bool _filling = false;
  bool _busy = false;

  /// What went wrong: a message of the page, or what was thrown (worded
  /// when it is shown).
  Object? _error;

  Pet get _pet => widget.pet;
  DateTime get _now => ref.read(healthClockProvider)();

  @override
  void initState() {
    super.initState();
    _lastSeen = _now;
    for (final c in [_description, _area, _phone, _extra]) {
      c.addListener(_changed);
    }
    ref.read(lostCardPhotoSourceProvider).photoOf(_pet).then((photo) {
      if (mounted && photo != null) setState(() => _profilePhoto = photo);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    for (final c in [_description, _area, _phone, _extra]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    // The preview follows every keystroke; filling the form from the saved
    // draft happens inside a build, which redraws anyway.
    if (!_filling) setState(() {});
  }

  /// Starts from what was written before. After the pet came home, only
  /// what stays true is kept: the description, the phone and the language.
  void _fill(LostPetCard? saved) {
    if (_filled) return;
    _filled = true;
    if (saved == null) return;
    _filling = true;
    _description.text = saved.description;
    _phone.text = saved.phone;
    _language = saved.language;
    if (saved.foundAt == null) {
      _area.text = saved.area;
      _extra.text = saved.extra;
      _lastSeen = saved.lastSeenAt ?? _lastSeen;
    }
    _filling = false;
  }

  /// Whether [value] cannot be a phone number (an empty one is fine).
  static bool _notAPhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return false;
    final digits = v.replaceAll(RegExp('[^0-9]'), '');
    return digits.length < 5 || RegExp(r'[^0-9+()\-\s.]').hasMatch(v);
  }

  String get _typedPhone => _phone.text.trim();
  bool get _phoneUsable => _typedPhone.isNotEmpty && !_notAPhone(_typedPhone);
  bool get _confirmed => _phoneUsable && _confirmedPhone == _typedPhone;

  LostCardContent _content(HealthProfile? profile) => LostCardContent(
    language: _language,
    petName: _pet.name,
    description: _description.text,
    area: _area.text,
    lastSeenAt: _lastSeen,
    microchipped: (profile?.microchip.trim() ?? '').isNotEmpty,
    // The number only appears once the owner has agreed to show it.
    phone: _confirmed ? _typedPhone : '',
    extra: _extra.text,
  );

  LostPetCard _draft({DateTime? foundAt}) => LostPetCard(
    petId: _pet.id,
    description: _description.text.trim(),
    area: _area.text.trim(),
    lastSeenAt: _lastSeen,
    phone: _typedPhone,
    extra: _extra.text.trim(),
    language: _language,
    foundAt: foundAt,
  );

  Future<void> _pickWhen() async {
    final now = _now;
    final day = await showDatePicker(
      context: context,
      initialDate: _lastSeen,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      currentDate: now,
      helpText: context.healthL10n.lostWhenHelp,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_lastSeen),
      helpText: context.healthL10n.lostTimeHelp,
    );
    if (!mounted) return;
    final picked = atTime(day, time ?? TimeOfDay.fromDateTime(_lastSeen));
    setState(() => _lastSeen = picked.isAfter(now) ? now : picked);
  }

  Future<void> _changePhoto() async {
    try {
      final file = await ref.read(attachmentPickerProvider).pickPhoto();
      if (file == null || !mounted) return;
      setState(() => _chosenPhoto = MemoryImage(file.bytes));
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  Future<void> _share({required bool asPdf}) async {
    if (!_form.currentState!.validate() || !_confirmed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Kept, so nothing is retyped next time. Sharing does not wait on it.
      try {
        await ref.read(lostCardProvider(_pet.id).notifier).save(_draft());
      } catch (_) {}
      final renderer = ref.read(lostCardRendererProvider);
      final png = await renderer.png(_cardKey);
      // A file's title is plain text: no direction marks.
      final title = stripBidiMarks(LostCardWords.of(_language).heading(_pet.name));
      final file = asPdf
          ? SharedFile(
              name: lostCardFileName(_pet.name, 'pdf'),
              mimeType: 'application/pdf',
              bytes: await renderer.pdf(png, title: title),
              subject: title,
            )
          : SharedFile(name: lostCardFileName(_pet.name, 'png'), mimeType: 'image/png', bytes: png, subject: title);
      final shared = await ref.read(fileSharerProvider).share(file);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = shared ? null : context.healthL10n.couldNotOpenShareSheet;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _backHome() async {
    setState(() => _busy = true);
    try {
      await ref.read(lostCardProvider(_pet.id).notifier).save(_draft(foundAt: _now));
      if (!mounted) return;
      Navigator.of(context).pop();
      showHealthSnack(context, context.healthL10n.lostGoodNews);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(lostCardProvider(_pet.id));
    final profile = ref.watch(healthProfileProvider(_pet.id)).value;
    final now = ref.watch(healthClockProvider)();
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final error = _error;

    Widget body;
    if (saved.isLoading && !saved.hasValue) {
      body = const HealthLoading();
    } else {
      // A draft that cannot be loaded never stands in the way of a card.
      _fill(saved.value);
      final photo = _chosenPhoto ?? _profilePhoto;
      final active = saved.value != null && saved.value!.foundAt == null;
      body = Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormLabel(l10n.lostCardSection),
            HealthCard(
              radius: AppSpacing.fieldRadius,
              padding: const EdgeInsetsDirectional.only(start: 10, end: 4, top: 8, bottom: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 52,
                      height: 52,
                      color: AppColors.sage,
                      child: photo == null
                          ? const Icon(Icons.pets_rounded, color: AppColors.ink)
                          : Image(
                              image: photo,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) => const Icon(Icons.pets_rounded, color: AppColors.ink),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photo == null ? l10n.lostNoPhoto : l10n.lostPetsPhoto(_pet.name),
                          style: AppText.cardTitle,
                        ),
                        Text(
                          _chosenPhoto != null
                              ? l10n.lostPhotoChosen
                              : photo != null
                              ? l10n.lostPhotoFromProfile
                              : l10n.lostPhotoHint,
                          style: AppText.secondary.copyWith(color: AppColors.brown),
                        ),
                      ],
                    ),
                  ),
                  HealthLink(
                    photo == null ? context.l10n.commonAdd : l10n.change,
                    key: const Key('lost-change-photo'),
                    icon: Icons.photo_library_rounded,
                    onPressed: _busy ? null : _changePhoto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('lost-description'),
              controller: _description,
              minLines: 2,
              maxLines: 5,
              maxLength: 400,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.lostDescription,
                hintText: l10n.lostDescriptionHint(_pet.name),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('lost-area'),
              controller: _area,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.lostArea, counterText: ''),
            ),
            const SizedBox(height: 6),
            FinePrint(
              looksLikeExactAddress(_area.text) ? l10n.lostAreaExact : l10n.lostAreaHint,
              key: const Key('lost-area-hint'),
              center: false,
            ),
            const SizedBox(height: 10),
            PickerTile(
              key: const Key('lost-when'),
              icon: Icons.schedule_rounded,
              label: l10n.lostWhen,
              value: format.relativeDayTime(_lastSeen, now),
              onTap: _pickWhen,
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('lost-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 40,
              // A phone number: left to right on every screen.
              textDirection: TextDirection.ltr,
              textAlign: context.isRtl ? TextAlign.end : TextAlign.start,
              decoration: InputDecoration(labelText: l10n.lostYourPhone, counterText: ''),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) => _notAPhone(value) ? l10n.validPhone : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('lost-extra'),
              controller: _extra,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.lostExtra, hintText: l10n.lostExtraHint, counterText: ''),
            ),
            FormLabel(l10n.lostLanguage),
            Wrap(
              spacing: 8,
              children: [
                for (final language in LostCardLanguage.values)
                  ChoiceChip(
                    key: ValueKey('lost-language-${language.code}'),
                    label: Text(lostCardLanguageName(language)),
                    selected: language == _language,
                    onSelected: (_) => setState(() => _language = language),
                  ),
              ],
            ),
            FormLabel(l10n.lostPreviewLabel),
            RepaintBoundary(
              key: _cardKey,
              child: LostCardView(key: const Key('lost-card-preview'), content: _content(profile), photo: photo),
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              clipBehavior: Clip.antiAlias,
              child: CheckboxListTile(
                key: const Key('lost-confirm-phone'),
                value: _confirmed,
                onChanged: _phoneUsable && !_busy
                    ? (value) => setState(() => _confirmedPhone = (value ?? false) ? _typedPhone : null)
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  _phoneUsable ? l10n.lostShowPhone(format.ltrInLine(_typedPhone)) : l10n.lostAddPhoneFirst,
                  style: AppText.body.copyWith(color: AppColors.ink),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error is String ? error : format.error(error),
                style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: l10n.shareAsImage,
              loading: _busy,
              onPressed: _confirmed ? () => _share(asPdf: false) : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('lost-share-pdf'),
              onPressed: _confirmed && !_busy ? () => _share(asPdf: true) : null,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
              icon: const Icon(Icons.print_rounded),
              label: Text(l10n.shareAsPdf),
            ),
            if (active)
              Center(
                child: HealthLink(
                  l10n.petIsBackHome(_pet.name),
                  key: const Key('lost-back-home'),
                  icon: Icons.home_rounded,
                  onPressed: _busy ? null : _backHome,
                ),
              ),
            const SizedBox(height: 12),
            FinePrint(l10n.lostFinePrint),
          ],
        ),
      );
    }

    return HealthPage(petId: _pet.id, title: l10n.petIsLost(_pet.name), child: body);
  }
}
