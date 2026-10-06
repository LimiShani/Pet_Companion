import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../../../services/community/data/members_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../feed/feed_controller.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../feed/post_card.dart';
import '../safety/safety_flows.dart';
import '../safety/safety_providers.dart';
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/section_state.dart';
import 'members_providers.dart';

/// A member's page: name, city, since when, the line they wrote about
/// themselves, and their posts. The member's own page edits that line;
/// someone else's offers blocking.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final profile = ref.watch(memberProfileProvider(memberId));
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    final mine = memberId == viewerId;
    final blocked = ref.watch(blockedIdsProvider).contains(memberId);
    final value = profile.value;

    final Widget body;
    if (value == null) {
      body = profile.isLoading
          ? const Center(child: CircularProgressIndicator())
          : profile.hasError
          ? SectionState(
              icon: Icons.cloud_off_rounded,
              title: l10n.memberLoadFailed,
              message: communityErrorText(context, profile.error),
              actionLabel: app.commonTryAgain,
              onAction: () => ref.invalidate(memberProfileProvider(memberId)),
            )
          : SectionState(
              icon: Icons.person_off_rounded,
              title: l10n.memberGoneTitle,
              message: l10n.memberGoneMessage,
            );
    } else {
      final posts = ref.watch(memberPostsProvider(memberId));
      final since = value.memberSince;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          16,
          AppSpacing.screen,
          24,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      AuthorAvatar(
                        name: value.name,
                        authorId: value.id,
                        size: 64,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoDirectionText(
                              l10n.memberName(value.name),
                              style: AppText.cardTitle.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              dotted([
                                if (value.city.isNotEmpty)
                                  l10n.inLine(value.city),
                                l10n.memberPostCount(value.postCount),
                              ]),
                              style: AppText.label.copyWith(
                                color: AppColors.brown,
                              ),
                            ),
                            if (since != null)
                              Text(
                                l10n.memberSince(
                                  AppFormat.of(context).monthYear(since),
                                ),
                                style: AppText.label.copyWith(
                                  color: AppColors.brown,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (value.bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AutoDirectionText(
                      value.bio,
                      style: AppText.body.copyWith(height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (mine)
                    OutlinedButton.icon(
                      onPressed: () => _editProfile(context, ref, value),
                      icon: const AppIcon(Icons.edit_outlined, size: 18),
                      label: Text(l10n.editProfile),
                    )
                  else if (blocked) ...[
                    Text(
                      l10n.blockedMemberNote,
                      style: AppText.body.copyWith(color: AppColors.brown),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => ref
                            .read(blockedMembersProvider.notifier)
                            .unblock(memberId),
                        child: Text(l10n.unblock),
                      ),
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: () => blockMemberFlow(
                        context,
                        ref,
                        memberId: memberId,
                        memberName: value.name,
                      ),
                      icon: const AppIcon(Icons.block_rounded, size: 18),
                      label: Text(
                        l10n.blockMember(
                          l10n.inLine(l10n.memberName(value.name)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!blocked) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
              child: Text(
                l10n.memberPosts,
                style: AppText.label.copyWith(
                  color: AppColors.brown,
                  fontSize: 13,
                ),
              ),
            ),
            switch (posts) {
              AsyncData(:final value) when value.isEmpty => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.memberPostCount(0),
                  style: AppText.body.copyWith(color: AppColors.brown),
                ),
              ),
              AsyncData(:final value) => Column(
                children: [
                  for (final post in value)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.cardGap,
                      ),
                      child: _MemberPost(post: post),
                    ),
                ],
              ),
              AsyncError(:final error) => Text(
                communityErrorText(context, error),
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ],
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: value == null
                ? l10n.memberTitle
                : l10n.memberName(value.name),
            showBack: true,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    MemberProfile profile,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => _ProfileForm(profile: profile),
    );
    if (saved == true) {
      ref.invalidate(memberProfileProvider(memberId));
    }
  }
}

/// A post on a member's page: as the feed knows it once liked or opened,
/// and opening the post page.
class _MemberPost extends ConsumerWidget {
  const _MemberPost({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PostCard(
      post: ref.watch(postProvider(post.id)) ?? post,
      onOpen: () {
        // Kept beside the feed, so the post page and its actions find it.
        ref.read(feedControllerProvider.notifier).keep(post);
        GoRouter.of(context).push(CommunityRoutes.post(post.id));
      },
    );
  }
}

/// The member's own line and city.
class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final MemberProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _bio = TextEditingController(text: widget.profile.bio);
  late final _city = TextEditingController(text: widget.profile.city);
  var _saving = false;

  @override
  void dispose() {
    _bio.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final viewer = ref.read(authControllerProvider).value;
    if (viewer == null || _saving) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    final done = context.communityL10n.profileSaved;
    setState(() => _saving = true);
    try {
      await ref
          .read(communityMembersRepositoryProvider)
          .updateMyProfile(viewer: viewer, bio: _bio.text, city: _city.text);
      navigator.pop(true);
      showCommunitySnack(messenger, done);
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.editProfile,
                style: AppText.cardTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.profilePublicNote,
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _bio,
                minLines: 2,
                maxLines: 4,
                maxLength: ProfileLimits.bio,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(ProfileLimits.bio),
                ],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.profileBio,
                  hintText: l10n.profileBioHint,
                  hintMaxLines: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _city,
                maxLength: ProfileLimits.city,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.profileCity,
                  hintText: l10n.profileCityHint,
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: l10n.saveChanges,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
