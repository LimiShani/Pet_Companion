import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../community_routes.dart';
import '../data/community_models.dart';
import '../data/guides_repository.dart';
import '../widgets/icon_disc.dart';
import 'guides_providers.dart';

/// The Guides section of the Community tab: search, category filter and
/// the list of guides.
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
    final library = ref.watch(guideLibraryProvider);
    final data = library.value;

    if (data == null) {
      if (library.isLoading) return const Center(child: CircularProgressIndicator());
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Cannot load the guides',
        message: communityErrorMessage(library.error ?? ''),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(guideLibraryProvider),
      );
    }

    final results = data.search(query: _search.text, categoryId: _categoryId);

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search guides',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.brown),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _search.clear,
                      tooltip: 'Clear search',
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
                label: 'All',
                selected: _categoryId == null,
                onSelected: () => setState(() => _categoryId = null),
              ),
              for (final category in data.categories) ...[
                const SizedBox(width: 8),
                _CategoryChip(
                  label: category.name,
                  selected: _categoryId == category.id,
                  onSelected: () => setState(() => _categoryId = category.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No guides match',
              message: 'Try a different word or another category.',
            ),
          )
        else
          for (final guide in results)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.cardGap),
              child: _GuideCard(guide: guide, category: data.categoryOf(guide)),
            ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.category});

  final Guide guide;
  final GuideCategory? category;

  @override
  Widget build(BuildContext context) {
    final meta = ['${guide.readingMinutes} min read', if (category != null) category!.name].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(CommunityRoutes.guide(guide.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconDisc(icon: category?.icon ?? Icons.menu_book_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guide.title, style: AppText.cardTitle.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(guide.summary, style: AppText.secondary.copyWith(color: AppColors.brown)),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      style: AppText.label.copyWith(color: AppColors.brown),
                      maxLines: 1,
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
