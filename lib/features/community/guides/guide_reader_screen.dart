import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../data/guides_repository.dart';
import 'guides_providers.dart';

/// Reads one guide: title, reading time, headed sections and the closing
/// note that it is general guidance.
class GuideReaderScreen extends ConsumerWidget {
  const GuideReaderScreen({super.key, required this.guideId});

  final String guideId;

  static final _paragraph = AppText.body.copyWith(fontSize: 16, height: 1.55, fontWeight: FontWeight.w500);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(guideLibraryProvider);
    final guide = library.value?.guideById(guideId);
    final category = guide == null ? null : library.value?.categoryOf(guide);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CoralHeader(title: 'Guide', showBack: true),
          Expanded(
            child: guide == null
                ? library.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : EmptyState(
                        icon: Icons.menu_book_rounded,
                        title: 'Guide not found',
                        message: 'This guide is not in the library any more.',
                        actionLabel: 'Back to the guides',
                        onAction: () => Navigator.of(context).maybePop(),
                      )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                    children: [
                      if (category != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: const ShapeDecoration(color: AppColors.yellow, shape: StadiumBorder()),
                            child: Text(category.name, style: AppText.label.copyWith(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Semantics(header: true, child: Text(guide.title, style: AppText.petName)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 16, color: AppColors.brown),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${guide.readingMinutes} min read',
                              style: AppText.secondary.copyWith(color: AppColors.brown),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(guide.intro, style: _paragraph),
                      for (final section in guide.sections) _Section(section: section),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                        ),
                        child: Text(guideDisclaimer, style: AppText.secondary.copyWith(height: 1.45)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final GuideSection section;

  @override
  Widget build(BuildContext context) {
    final paragraph = GuideReaderScreen._paragraph;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(section.heading, style: AppText.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        for (final text in section.paragraphs)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: paragraph)),
        if (section.bullets.isNotEmpty) const SizedBox(height: 2),
        for (final bullet in section.bullets)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 10),
                  child: ExcludeSemantics(child: Text('•', style: paragraph.copyWith(fontWeight: FontWeight.w800))),
                ),
                Expanded(child: Text(bullet, style: paragraph)),
              ],
            ),
          ),
        for (final text in section.after)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: paragraph)),
      ],
    );
  }
}
