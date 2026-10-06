import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../community_words.dart';
import '../../../services/community/data/guides_repository.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../widgets/advice_notice.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/small_tag.dart';
import '../widgets/section_state.dart';
import 'guides_providers.dart';

/// Opens a guide's source in the browser. Returns whether it opened. Behind
/// a provider so tests do not reach the platform.
final guideSourceOpenerProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Reads one guide: title, reading time, where the guide comes from
/// ("About this guide"), headed sections, and the closing note that it is
/// general guidance.
class GuideReaderScreen extends ConsumerWidget {
  const GuideReaderScreen({super.key, required this.guideId});

  final String guideId;

  static final _paragraph = AppText.body.copyWith(
    fontSize: 16,
    height: 1.55,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'community.guides.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final library = ref.watch(guideLibraryProvider);
    final guide = library.value?.guideById(guideId);
    final category = guide == null ? null : library.value?.categoryOf(guide);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.guideTitle, showBack: true),
          Expanded(
            child: guide == null
                ? library.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SectionState(
                          icon: Icons.menu_book_rounded,
                          title: l10n.guideNotFoundTitle,
                          message: l10n.guideNotFoundMessage,
                          actionLabel: l10n.backToGuides,
                          onAction: () => Navigator.of(context).maybePop(),
                        )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: const ShapeDecoration(
                                color: AppColors.yellow,
                                shape: StadiumBorder(),
                              ),
                              child: Text(
                                l10n.categoryName(category),
                                style: AppText.label.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (!guide.translated) SmallTag.englishOnly(l10n),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // The guide's own words read in the direction of
                      // their language, whatever the app's language is.
                      Directionality(
                        textDirection: guide.language.direction,
                        child: Semantics(
                          header: true,
                          child: Text(guide.title, style: AppText.petName),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const AppIcon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: AppColors.brown,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              dotted([
                                l10n.readTime(guide.readingMinutes),
                                ?l10n.forWhom(guide.audience),
                              ]),
                              style: AppText.secondary.copyWith(
                                color: AppColors.brown,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Before the text, so nobody reads advice without
                      // knowing where it comes from.
                      _AboutGuide(guide: guide),
                      const SizedBox(height: 14),
                      Directionality(
                        textDirection: guide.language.direction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(guide.intro, style: _paragraph),
                            for (final section in guide.sections)
                              _Section(section: section),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.fieldRadius,
                          ),
                        ),
                        child: Text(
                          l10n.guideDisclaimer,
                          style: AppText.secondary.copyWith(height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => contactProfessional(context, ref),
                        icon: const AppIcon(Icons.call_rounded, size: 20),
                        label: Text(l10n.contactProfessional),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Where a guide comes from: who wrote it and in what capacity, whether a
/// professional reviewed it, when it last changed and what it cites.
///
/// It says only what is recorded with the guide. Without a review on record
/// it says so in plain words, in the language on screen.
class _AboutGuide extends ConsumerWidget {
  const _AboutGuide({required this.guide});

  final Guide guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'community.guides.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final format = AppFormat.of(context);
    final review = guide.review;
    final sources = guide.sources;

    return Card(
      key: const Key('about-guide'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.aboutThisGuide,
              style: AppText.label.copyWith(color: AppColors.brown),
            ),
            const SizedBox(height: 2),
            // The author's name and role are part of the guide's own text:
            // written per language, and shown as written.
            _AboutRow(
              icon: Icons.edit_rounded,
              label: l10n.writtenBy,
              value: guide.author.name,
              detail: guide.author.role,
              written: true,
            ),
            const Divider(),
            if (review == null)
              _AboutRow(
                icon: Icons.shield_outlined,
                label: l10n.professionalReview,
                value: l10n.notReviewedByVet,
              )
            else
              _AboutRow(
                key: const Key('guide-review'),
                icon: Icons.verified_user_rounded,
                label: l10n.reviewedBy,
                value: l10n.inLine(review.reviewerName),
                detail: dotted([
                  l10n.inLine(review.reviewerRole),
                  l10n.reviewedOn(format.date(review.reviewedAt.toDateTime())),
                ]),
                highlighted: true,
              ),
            const Divider(),
            _AboutRow(
              icon: Icons.event_rounded,
              label: l10n.lastUpdated,
              value: format.date(guide.updatedAt),
            ),
            const Divider(),
            if (sources.isEmpty)
              _AboutRow(
                icon: Icons.menu_book_rounded,
                label: l10n.sources,
                value: l10n.noSources,
                detail: l10n.noSourcesDetail,
              )
            else
              _AboutRow(
                icon: Icons.menu_book_rounded,
                label: l10n.sources,
                children: [
                  for (final source in sources) _SourceLine(source: source),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.detail,
    this.children = const [],
    this.highlighted = false,
    this.written = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? detail;
  final List<Widget> children;

  /// A sage band behind the row: only for a real, current review.
  final bool highlighted;

  /// Whether [value] and [detail] are somebody's own words (the author's
  /// name and role), which read in their own direction.
  final bool written;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.guides.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final valueStyle = AppText.body.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w800,
    );
    final detailStyle = AppText.label.copyWith(
      color: AppColors.brown,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppIcon(
            icon,
            size: 20,
            color: highlighted ? AppColors.ink : AppColors.brown,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: AppText.navLabel.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.brown,
                ),
              ),
              if (value != null)
                written
                    ? AutoDirectionText(value!, style: valueStyle)
                    : Text(value!, style: valueStyle),
              if (detail != null)
                written
                    ? AutoDirectionText(detail!, style: detailStyle)
                    : Text(detail!, style: detailStyle),
              ...children,
            ],
          ),
        ),
      ],
    );

    return MergeSemantics(
      child: highlighted
          ? Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF1E6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: row,
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: row,
            ),
    );
  }
}

/// One cited source. With a link it opens in the browser.
class _SourceLine extends ConsumerWidget {
  const _SourceLine({required this.source});

  final GuideSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'community.guides.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final uri = source.url == null ? null : Uri.tryParse(source.url!);
    final text = source.publisher == null
        ? source.title
        : l10n.sourceWithPublisher(source.title, source.publisher!);
    final style = AppText.body.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );

    if (uri == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: AutoDirectionText(text, style: style),
      );
    }
    return InkWell(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        var opened = false;
        try {
          opened = await ref.read(guideSourceOpenerProvider)(uri);
        } catch (_) {}
        if (!opened) showCommunitySnack(messenger, l10n.sourceOpenFailed);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: AutoDirectionText(
                text,
                style: style.copyWith(color: AppColors.coralDark),
              ),
            ),
            const SizedBox(width: 8),
            // Mirrors itself in a right-to-left layout.
            const AppIcon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppColors.coralDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final GuideSection section;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.guides.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final paragraph = GuideReaderScreen._paragraph;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            section.heading,
            style: AppText.cardTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (final text in section.paragraphs)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(text, style: paragraph),
          ),
        if (section.bullets.isNotEmpty) const SizedBox(height: 2),
        for (final bullet in section.bullets)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, end: 10),
                  child: ExcludeSemantics(
                    child: Text(
                      '•',
                      style: paragraph.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                Expanded(child: Text(bullet, style: paragraph)),
              ],
            ),
          ),
        for (final text in section.after)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(text, style: paragraph),
          ),
      ],
    );
  }
}
