import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../community_words.dart';
import '../data/community_models.dart';
import '../data/photo_picker.dart';
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import 'feed_controller.dart';
import 'post_actions.dart';

/// Opens the full-screen composer above the bottom navigation bar.
Future<void> openPostComposer(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (context) => const PostComposerScreen()),
  );
}

/// Full-screen form for a new post: text, an optional pet tag and one
/// optional photo.
class PostComposerScreen extends ConsumerStatefulWidget {
  const PostComposerScreen({super.key});

  @override
  ConsumerState<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends ConsumerState<PostComposerScreen> {
  final _text = TextEditingController();
  String? _petId;
  PickedPhoto? _photo;
  var _posting = false;

  bool get _hasText => _text.text.trim().isNotEmpty;
  bool get _dirty => _hasText || _photo != null;

  @override
  void initState() {
    super.initState();
    // The pet shown across the app starts tagged; one tap removes the tag.
    _petId = ref.read(selectedPetProvider).id;
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorWords = communityErrorWords(context);
    String? petName;
    for (final pet in ref.read(petsProvider)) {
      if (pet.id == _petId) petName = pet.name;
    }

    setState(() => _posting = true);
    try {
      await ref.read(feedControllerProvider.notifier).create(text: _text.text, petName: petName, photo: _photo);
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.keepWriting)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.discard)),
        ],
      ),
    );
    if (discard == true) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
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
              title: l10n.newPost,
              showBack: true,
              actions: [
                FilledButton(
                  onPressed: _hasText && !_posting ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.ink,
                    disabledBackgroundColor: AppColors.yellow.withValues(alpha: 0.45),
                    disabledForegroundColor: AppColors.ink.withValues(alpha: 0.55),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: _posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink),
                        )
                      : Text(l10n.postButton),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 24),
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
                              style: AppText.cardTitle.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l10n.composerAudience,
                              style: AppText.label.copyWith(color: AppColors.brown),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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
                    style: AppText.body.copyWith(fontSize: 16, height: 1.5),
                    decoration: InputDecoration(
                      hintText: l10n.composerHint,
                      border: _fieldBorder,
                      enabledBorder: _fieldBorder,
                      focusedBorder: _fieldBorder.copyWith(
                        borderSide: const BorderSide(color: AppColors.coral, width: 2),
                      ),
                      counterStyle: AppText.label.copyWith(color: AppColors.brown),
                    ),
                  ),
                  if (pets.isNotEmpty) ...[
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
                            onSelected: (selected) => setState(() => _petId = selected ? pet.id : null),
                          ),
                      ],
                    ),
                  ],
                  _Label(l10n.composerPhoto),
                  if (_photo != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.memory(
                              _photo!.bytes,
                              fit: BoxFit.cover,
                              semanticLabel: l10n.composerPhotoPreview,
                              errorBuilder: (context, error, stack) => ColoredBox(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: const Center(child: Icon(Icons.image_rounded, size: 48, color: AppColors.brown)),
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
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _SourceButton(
                          icon: Icons.photo_library_rounded,
                          label: l10n.gallery,
                          onPressed: _posting ? null : () => _pick(PhotoSource.gallery),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SourceButton(
                          icon: Icons.photo_camera_rounded,
                          label: l10n.camera,
                          onPressed: _posting ? null : () => _pick(PhotoSource.camera),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(text, style: AppText.label.copyWith(color: AppColors.brown, fontSize: 13)),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
      icon: Icon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
