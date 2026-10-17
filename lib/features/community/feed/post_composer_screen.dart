import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../community_words.dart';
import '../../../services/community/data/audience.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/findvet/regions/regions.dart'
    show Locality, vetRegions;
import '../data/photo_picker.dart';
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import 'feed_controller.dart';
import 'near_me.dart';
import 'post_actions.dart';
import '../safety/safety_flows.dart';

/// Opens the full-screen composer above the bottom navigation bar: for a
/// new post (of [kind], a moment unless told), or to change [editing] (one
/// of the member's own).
Future<void> openPostComposer(
  BuildContext context, {
  Post? editing,
  PostKind? kind,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => PostComposerScreen(editing: editing, kind: kind),
    ),
  );
}

/// Full-screen form for a post: its kind, text, an optional pet tag and one
/// optional photo. Editing changes only the text and the kind.
class PostComposerScreen extends ConsumerStatefulWidget {
  const PostComposerScreen({super.key, this.editing, this.kind});

  final Post? editing;

  /// The kind a new post starts as (the Add sheet's row); a moment if
  /// null. The member can still change it.
  final PostKind? kind;

  @override
  ConsumerState<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends ConsumerState<PostComposerScreen> {
  static const placeKey = ValueKey('compose-place');
  static const localityKey = ValueKey('compose-locality');

  final _text = TextEditingController();
  final _place = TextEditingController();

  /// The city the post is about, once the member chose one ("Everywhere"
  /// is `null`); until then the city of their member page.
  String? _locality;
  var _localityChosen = false;
  String? _petId;
  PickedPhoto? _photo;
  late var _kind = widget.kind ?? PostKind.moment;
  var _posting = false;

  Post? get _editing => widget.editing;
  bool get _hasText => _text.text.trim().isNotEmpty;
  bool get _dirty => _editing == null
      ? _hasText || _photo != null || _kind != (widget.kind ?? PostKind.moment)
      : _text.text.trim() != _editing!.text || _kind != _editing!.kind;

  @override
  void initState() {
    super.initState();
    if (_editing case final post?) {
      _text.text = post.text;
      _kind = post.kind;
    } else {
      // The pet shown across the app starts tagged; one tap removes it.
      _petId = ref.read(selectedPetProvider).id;
    }
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _place.dispose();
    super.dispose();
  }

  /// Where the post is about: the member's choice, else their city.
  String? get _localityCode =>
      _localityChosen ? _locality : ref.read(myCityProvider).value?.code;

  Future<void> _chooseLocality(String choice) async {
    switch (choice) {
      case 'everywhere':
        setState(() {
          _localityChosen = true;
          _locality = null;
        });
      case 'other':
        final city = await showModalBottomSheet<Locality>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _CitySheet(),
        );
        if (city != null && mounted) {
          setState(() {
            _localityChosen = true;
            _locality = city.code;
          });
        }
      default:
        setState(() {
          _localityChosen = true;
          _locality = choice;
        });
    }
  }

  Future<void> _pick(PhotoSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    try {
      final photo = await ref.read(photoPickerProvider).pick(source);
      if (photo != null && mounted) setState(() => _photo = photo);
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  Future<void> _submit() async {
    if (!_hasText || _posting) return;
    if (!await ensureCommunityRules(context, ref)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorWords = communityErrorWords(context);
    final saved = context.communityL10n.postSaved;
    String? petName;
    var audience = Audience.everyone;
    for (final pet in ref.read(petsProvider)) {
      if (pet.id == _petId) {
        petName = pet.name;
        // The post is about this pet: it shows under its animal's chip.
        audience = audienceOfSpecies(pet.species);
      }
    }

    setState(() => _posting = true);
    try {
      final feed = ref.read(feedControllerProvider.notifier);
      if (_editing case final post?) {
        await feed.edit(post, text: _text.text, kind: _kind);
        showCommunitySnack(messenger, saved);
      } else {
        final place = _place.text.trim();
        await feed.create(
          text: _text.text,
          petName: petName,
          photo: _photo,
          kind: _kind,
          audience: audience,
          localityCode: _localityCode,
          placeName: _kind == PostKind.recommendation && place.isNotEmpty
              ? place
              : null,
        );
      }
      navigator.pop();
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final navigator = Navigator.of(context);
    final l10n = context.communityL10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardTitle),
        content: Text(l10n.discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keepWriting),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (discard == true) navigator.pop();
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: widget.editing == null
        ? 'community.feed.post'
        : 'community.feed.edit',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final editing = _editing != null;
    final user = ref.watch(authControllerProvider).value;
    final pets = ref.watch(petsProvider);
    final storedName = storedAuthorName(user?.displayName);

    return PopScope(
      canPop: !_dirty || _posting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoralHeader(
              title: editing ? l10n.editPostTitle : l10n.newPost,
              showBack: true,
              actions: [
                FilledButton(
                  onPressed: _hasText && !_posting && (!editing || _dirty)
                      ? _submit
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.ink,
                    disabledBackgroundColor: AppColors.yellow.withValues(
                      alpha: 0.45,
                    ),
                    disabledForegroundColor: AppColors.ink.withValues(
                      alpha: 0.55,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: _posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.ink,
                          ),
                        )
                      : Text(editing ? l10n.saveChanges : l10n.postButton),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  16,
                  AppSpacing.screen,
                  24,
                ),
                children: [
                  Row(
                    children: [
                      AuthorAvatar(name: storedName, authorId: user?.id ?? ''),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoDirectionText(
                              l10n.memberName(storedName),
                              style: AppText.cardTitle.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l10n.composerAudience,
                              style: AppText.label.copyWith(
                                color: AppColors.brown,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _Label(l10n.composerKind),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final kind in PostKind.values)
                        ChoiceChip(
                          key: ValueKey('compose-kind-${kind.name}'),
                          label: Text(l10n.postKind(kind)),
                          selected: kind == _kind,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _kind = kind),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _text,
                    autofocus: true,
                    minLines: 5,
                    maxLines: 12,
                    maxLength: CommunityLimits.postLength,
                    textCapitalization: TextCapitalization.sentences,
                    // The post reads in the direction of what is typed, as
                    // it will in the feed; an empty field follows the screen.
                    textDirection: contentDirection(context, _text.text),
                    style: AppText.bodyLarge.copyWith(height: 1.5),
                    decoration: InputDecoration(
                      hintText: l10n.composerHintFor(_kind),
                      border: _fieldBorder,
                      enabledBorder: _fieldBorder,
                      focusedBorder: _fieldBorder.copyWith(
                        borderSide: const BorderSide(
                          color: AppColors.coral,
                          width: 2,
                        ),
                      ),
                      counterStyle: AppText.label.copyWith(
                        color: AppColors.brown,
                      ),
                    ),
                  ),
                  if (_kind == PostKind.recommendation && !editing) ...[
                    const SizedBox(height: 8),
                    TextField(
                      key: placeKey,
                      controller: _place,
                      maxLength: CommunityLimits.placeNameLength,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l10n.composerPlace,
                        helperText: l10n.composerPlaceHelp,
                        helperMaxLines: 2,
                      ),
                    ),
                  ],
                  if (!editing) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _LocalityChip(
                        key: localityKey,
                        current: _localityChosen
                            ? _locality
                            : ref.watch(myCityProvider).value?.code,
                        mine: ref.watch(myCityProvider).value,
                        onChosen: _chooseLocality,
                      ),
                    ),
                  ],
                  if (pets.isNotEmpty && !editing) ...[
                    _Label(l10n.composerAbout),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final pet in pets)
                          ChoiceChip(
                            label: Text(pet.name),
                            selected: pet.id == _petId,
                            showCheckmark: false,
                            onSelected: (selected) => setState(
                              () => _petId = selected ? pet.id : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (!editing) _Label(l10n.composerPhoto),
                  if (_photo != null && !editing) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.fieldRadius,
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.memory(
                              _photo!.bytes,
                              fit: BoxFit.cover,
                              semanticLabel: l10n.composerPhotoPreview,
                              errorBuilder: (context, error, stack) =>
                                  ColoredBox(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                                    child: const Center(
                                      child: AppIcon(
                                        Icons.image_rounded,
                                        size: 48,
                                        color: AppColors.brown,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: 8,
                          end: 8,
                          child: IconButton.filled(
                            onPressed: () => setState(() => _photo = null),
                            tooltip: l10n.removePhoto,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0x8C3C190A),
                              foregroundColor: AppColors.white,
                            ),
                            icon: const AppIcon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!editing)
                  Row(
                    children: [
                      Expanded(
                        child: _SourceButton(
                          icon: Icons.photo_library_rounded,
                          label: l10n.gallery,
                          onPressed: _posting
                              ? null
                              : () => _pick(PhotoSource.gallery),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SourceButton(
                          icon: Icons.photo_camera_rounded,
                          label: l10n.camera,
                          onPressed: _posting
                              ? null
                              : () => _pick(PhotoSource.camera),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rounder than the theme's field: this one is a big card.
  static final _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
    borderSide: const BorderSide(color: Colors.transparent),
  );
}

/// "Near Petah Tikva ▾" / "Everywhere ▾": a menu of the member's city,
/// another city and everywhere.
class _LocalityChip extends StatelessWidget {
  const _LocalityChip({
    super.key,
    required this.current,
    required this.mine,
    required this.onChosen,
  });

  final String? current;
  final Locality? mine;
  final ValueChanged<String> onChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final language =
        Localizations.localeOf(context).languageCode == 'he' ? 'he' : 'en';
    final city = _localityOf(current);
    final label = city == null
        ? l10n.composerEverywhere
        : l10n.composerNear(city.nameIn(language));
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onChosen,
      itemBuilder: (context) => [
        if (mine case final mine?)
          PopupMenuItem(
            value: mine.code,
            child: Text(l10n.composerNear(mine.nameIn(language))),
          ),
        if (city != null && city.code != mine?.code)
          PopupMenuItem(
            value: city.code,
            child: Text(l10n.composerNear(city.nameIn(language))),
          ),
        PopupMenuItem(
          key: const ValueKey('compose-locality-other'),
          value: 'other',
          child: Text(l10n.composerOtherCity),
        ),
        PopupMenuItem(
          key: const ValueKey('compose-locality-everywhere'),
          value: 'everywhere',
          child: Text(l10n.composerEverywhere),
        ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD9CBB3), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(Icons.place_rounded, size: 18, color: AppColors.ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label ▾',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.secondary.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Locality? _localityOf(String? code) {
  if (code == null) return null;
  for (final region in vetRegions) {
    final locality = region.localityByCode(code);
    if (locality != null) return locality;
  }
  return null;
}

/// "Which city?": a search over the app's localities.
class _CitySheet extends StatefulWidget {
  const _CitySheet();

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final language =
        Localizations.localeOf(context).languageCode == 'he' ? 'he' : 'en';
    final found = [
      for (final region in vetRegions)
        ...region.findLocalities(_query, limit: 8),
    ].take(8).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        16,
        AppSpacing.screen,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.composerCityTitle, style: AppText.heading),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('compose-city-field'),
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.composerCitySearch),
            onChanged: (text) => setState(() => _query = text),
          ),
          const SizedBox(height: 8),
          for (final city in found)
            ListTile(
              key: ValueKey('compose-city-${city.code}'),
              title: Text(city.nameIn(language)),
              onTap: () => Navigator.of(context).pop(city),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.feed.post',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        text,
        style: AppText.label.copyWith(color: AppColors.brown, fontSize: 13),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.feed.post',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      icon: AppIcon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
