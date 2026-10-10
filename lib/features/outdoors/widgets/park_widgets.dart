import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../platform/feature_ui.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../outdoors_words.dart';

/// The icon of each detail, on tags, chips and the details grid.
IconData parkDetailIcon(ParkDetail detail) => switch (detail) {
  ParkDetail.fenced => Icons.fence_rounded,
  ParkDetail.water => Icons.water_drop_rounded,
  ParkDetail.shade => Icons.park_rounded,
  ParkDetail.lighting => Icons.lightbulb_rounded,
  ParkDetail.smallDogs => Icons.pets_rounded,
  ParkDetail.benches => Icons.chair_alt_rounded,
};

/// A small rounded label: "Fenced", "Water tap", "Closed for renovation".
class ParkTag extends StatelessWidget {
  const ParkTag(this.label, {super.key, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: ShapeDecoration(
        color: color ?? AppColors.sage.withValues(alpha: 0.45),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 13, color: AppColors.ink),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AppText.navLabel.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The tags of what a park is known to have (unknown details are simply
/// not shown), and "Closed for renovation" first when it is.
class ParkTags extends StatelessWidget {
  const ParkTags(this.park, {super.key});

  final DogPark park;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final tags = [
      if (park.isClosed)
        ParkTag(
          l10n.closedLabel,
          icon: Icons.construction_rounded,
          color: AppColors.yellow,
        ),
      for (final detail in park.has)
        ParkTag(l10n.detail(detail), icon: parkDetailIcon(detail)),
    ];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: tags);
  }
}

/// One park on a list: its name, city and distance, its tags, and a star
/// when it is one of "My parks".
class ParkCard extends StatelessWidget {
  const ParkCard({
    super.key,
    required this.listing,
    required this.showDistance,
    required this.onTap,
    this.trailing,
  });

  static Key keyOf(String parkId) => Key('park-card-$parkId');

  /// The slot another feature (meetups) fills under the tags: "Meetup
  /// today". It gets `parkId`; empty, it takes no room.
  static const meetupsSlot = 'park-card-meetups';

  final ParkListing listing;
  final bool showDistance;
  final VoidCallback onTap;

  /// Replaces the star (a park picker shows a "choose" mark).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final park = listing.park;
    final city = localityName(park.localityCode, language);
    final distance = showDistance && listing.distanceM != null
        ? l10n.distance(listing.distanceM!, language)
        : null;
    final subtitle = [?city, ?distance].join(' · ');

    return Material(
      key: keyOf(park.id),
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: park.isClosed
                      ? AppColors.yellow.withValues(alpha: 0.6)
                      : AppColors.sage.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const AppIcon(
                  Icons.park_rounded,
                  color: AppColors.ink,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.parkTitle(park, language),
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: AppText.secondary.copyWith(
                            color: AppColors.brown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (park.isClosed || park.has.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ParkTags(park),
                    ],
                    featureSlot(meetupsSlot, '', {'parkId': park.id}),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (listing.saved)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Semantics(
                    label: l10n.myParks,
                    child: const AppIcon(
                      Icons.star_rounded,
                      color: AppColors.coralDark,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Map data © OpenStreetMap contributors": the licence credit.
class OsmCredit extends StatelessWidget {
  const OsmCredit({super.key});

  static const creditKey = Key('parks-osm-credit');

  @override
  Widget build(BuildContext context) {
    return Text(
      context.outdoorsL10n.osmCredit,
      key: creditKey,
      style: AppText.label.copyWith(color: AppColors.brown),
      textAlign: TextAlign.center,
    );
  }
}
