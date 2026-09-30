import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../data/audience.dart';
import '../data/guides_repository.dart';
import '../widgets/icon_disc.dart';
import '../widgets/scope_bar.dart';
import '../widgets/section_state.dart';
import '../widgets/small_tag.dart';
import 'guides_providers.dart';

/// The Guides section of the Community tab: the animal chips, search, the
/// category filter and the list of guides.
class GuidesSection extends ConsumerStatefulWidget {
  const GuidesSection({super.key});

  @override
  ConsumerState<GuidesSection> createState() => _GuidesSectionState();
}

class _GuidesSectionState extends ConsumerState<GuidesSection> {
  final _search = TextEditingController();
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final library = ref.watch(guideLibraryProvider);
    final scope = ref.watch(communityScopeProvider);
    final data = library.value;

    if (data == null) {
      if (library.isLoading) return const Center(child: CircularProgressIndicator());
      return SectionState(
        icon: Icons.cloud_off_rounded,
        title: l10n.guidesLoadFailed,
        message: communityErrorText(context, library.error),
        actionLabel: context.l10n.commonTryAgain,
        onAction: () => ref.invalidate(guideLibraryProvider),
      );
    }

    final categories = data.categoriesIn(scope);
    // A category chosen under another animal may not exist under this one.
    final categoryId = categories.any((c) => c.id == _categoryId) ? _categoryId : null;
    final results = data.search(query: _search.text, categoryId: categoryId, scope: scope);
    final everywhere =
        results.isEmpty && scope != CommunityScope.everything ? data.search(query: _search.text).length : 0;

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        const ScopeBar(what: ScopeBarSubject.guides),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            // A search reads in the direction of what is typed.
            textDirection: contentDirection(context, _search.text),
            decoration: InputDecoration(
              hintText: l10n.searchGuides,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.brown),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _search.clear,
                      tooltip: l10n.clearSearch,
                      icon: const Icon(Icons.close_rounded, color: AppColors.brown),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Row(
            children: [
              _CategoryChip(
                id: 'all',
                label: l10n.categoryAll,
                selected: categoryId == null,
                onSelected: () => setState(() => _categoryId = null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                _CategoryChip(
                  id: category.id,
                  label: l10n.categoryName(category),
                  selected: categoryId == category.id,
                  onSelected: () => setState(() => _categoryId = category.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: everywhere > 0
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n.noGuidesFor(scope),
                    message: l10n.matchesElsewhere(everywhere),
                    actionLabel: l10n.searchEverything,
                    onAction: () {
                      setState(() => _categoryId = null);
                      ref.read(communityScopeProvider.notifier).select(CommunityScope.everything);
                    },
                  )
                : EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n.noGuidesMatchTitle,
                    message: l10n.noGuidesMatchMessage,
                  ),
          )
        else
          for (final guide in results)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.cardGap),
              child: _GuideCard(
                guide: guide,
                category: data.categoryOf(guide),
                // Under Everything each guide says which animal it is for.
                showAudience: scope == CommunityScope.everything,
              ),
            ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.id, required this.label, required this.selected, required this.onSelected});

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: ValueKey('category-$id'),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.category, required this.showAudience});

  final Guide guide;
  final GuideCategory? category;
  final bool showAudience;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final format = AppFormat.of(context);
    final meta = dotted([
      l10n.readTime(guide.readingMinutes),
      if (category != null) l10n.categoryName(category!),
    ]);
    final small = AppText.label.copyWith(color: AppColors.brown);
    final audienceTag = showAudience ? SmallTag.forAudience(l10n, guide.audience) : null;
    final tags = [
      ?audienceTag,
      if (guide.review != null) SmallTag.reviewed(l10n),
      if (!guide.translated) SmallTag.englishOnly(l10n),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('guide-${guide.id}'),
        onTap: () => context.go(CommunityRoutes.guide(guide.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconDisc(icon: category?.icon ?? Icons.menu_book_rounded),
              const SizedBox(width: 14),
              Expanded(
                // The guide's own words read in the direction of their
                // language, whatever the app's language is.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Directionality(
                      textDirection: guide.language.direction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(guide.title, style: AppText.cardTitle.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(guide.summary, style: AppText.secondary.copyWith(color: AppColors.brown)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(meta, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: tags),
                    ],
                    const SizedBox(height: 4),
                    // Who wrote it and when: shown before anyone opens it.
                    Text(
                      dotted([
                        l10n.guideBy(l10n.inLine(guide.author.name)),
                        l10n.guideUpdated(format.date(guide.updatedAt)),
                      ]),
                      style: small,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
