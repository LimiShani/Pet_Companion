import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/findvet/regions/regions.dart' show vetRegions;
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/area_disc.dart';
import '../community_routes.dart';
import '../community_words.dart';
import 'feed_controller.dart';

/// A place members recommend: the recommendations with the same place
/// name in the same city.
class RecommendedPlace {
  const RecommendedPlace(this.name, this.localityCode, this.posts);

  final String name;
  final String? localityCode;

  /// Newest first.
  final List<Post> posts;
}

/// The places of the recommendations among [posts], the most recommended
/// first, then the most recent.
List<RecommendedPlace> recommendedPlaces(List<Post> posts) {
  final groups = <String, List<Post>>{};
  for (final post in posts) {
    final name = post.placeName?.trim() ?? '';
    if (post.kind != PostKind.recommendation || name.isEmpty) continue;
    groups
        .putIfAbsent('${name.toLowerCase()}|${post.localityCode ?? ''}', () => [])
        .add(post);
  }
  final places = [
    for (final list in groups.values)
      if (list..sort((a, b) => b.createdAt.compareTo(a.createdAt))
          case [final newest, ...])
        // The newest recommendation's spelling.
        RecommendedPlace(newest.placeName!.trim(), newest.localityCode, list),
  ];
  places.sort((a, b) {
    final count = b.posts.length.compareTo(a.posts.length);
    if (count != 0) return count;
    return b.posts.first.createdAt.compareTo(a.posts.first.createdAt);
  });
  return places;
}

/// "Places" above the posts of a search: up to three recommended places
/// (all of them after "Show all places"), then the heading "Posts". A
/// place with one recommendation opens it; with more, the search looks
/// for that place.
class PlacesGroup extends ConsumerStatefulWidget {
  const PlacesGroup({super.key, required this.posts});

  static const groupKey = Key('feed-places');
  static const allKey = Key('feed-places-all');
  static Key placeKey(int index) => Key('feed-place-$index');

  final List<Post> posts;

  @override
  ConsumerState<PlacesGroup> createState() => _PlacesGroupState();
}

class _PlacesGroupState extends ConsumerState<PlacesGroup> {
  var _all = false;

  @override
  Widget build(BuildContext context) {
    final places = recommendedPlaces(widget.posts);
    if (places.isEmpty) return const SizedBox.shrink();
    final l10n = context.communityL10n;
    final language = Localizations.localeOf(context).languageCode == 'he' ? 'he' : 'en';
    final shown = _all ? places : places.take(3).toList();
    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 8),
      child: Text(
        text,
        style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w800),
      ),
    );

    return Padding(
      key: PlacesGroup.groupKey,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(l10n.searchPlaces),
          for (final (index, place) in shown.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                key: PlacesGroup.placeKey(index),
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => place.posts.length == 1
                      ? context.go(CommunityRoutes.post(place.posts.single.id))
                      : ref.read(feedFilterProvider.notifier).search(place.name),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
                      child: Row(
                        children: [
                          const AreaDisc(Icons.place_rounded, area: AppArea.community),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  dotted([
                                    ?_cityName(place.localityCode, language),
                                    l10n.placeRecommendations(place.posts.length),
                                  ]),
                                  style: AppText.secondary.copyWith(color: AppColors.brown),
                                ),
                              ],
                            ),
                          ),
                          const AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!_all && places.length > 3)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: PlacesGroup.allKey,
                onPressed: () => setState(() => _all = true),
                child: Text(l10n.searchAllPlaces(places.length)),
              ),
            ),
          heading(l10n.searchPostsHeading),
        ],
      ),
    );
  }
}

/// The name of the locality with [code], or `null`.
String? _cityName(String? code, String language) {
  if (code == null) return null;
  for (final region in vetRegions) {
    final locality = region.localityByCode(code);
    if (locality != null) return locality.nameIn(language);
  }
  return null;
}
