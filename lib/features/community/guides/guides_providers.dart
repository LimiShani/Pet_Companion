import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/community/data/audience.dart';
import '../../../services/community/data/community_language.dart';
import '../../../services/community/data/community_providers.dart';
import '../../../services/community/data/guides_repository.dart';
import '../feed/feed_controller.dart' show noRetry;

/// Everything the guides screens need, loaded together.
class GuideLibrary {
  const GuideLibrary({required this.categories, required this.guides});

  final List<GuideCategory> categories;
  final List<Guide> guides;

  GuideCategory? categoryOf(Guide guide) {
    for (final c in categories) {
      if (c.id == guide.categoryId) return c;
    }
    return null;
  }

  Guide? guideById(String id) {
    for (final g in guides) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// The categories that have at least one guide under [scope], in display
  /// order.
  List<GuideCategory> categoriesIn(CommunityScope scope) => [
    for (final c in categories)
      if (guides.any((g) => g.categoryId == c.id && scope.shows(g.audience))) c,
  ];

  /// Guides under [scope], in [categoryId] (all when `null`), that match
  /// [query].
  List<Guide> search({
    String query = '',
    String? categoryId,
    CommunityScope scope = CommunityScope.everything,
  }) => [
    for (final g in guides)
      if (scope.shows(g.audience) &&
          (categoryId == null || g.categoryId == categoryId) &&
          g.matches(query))
        g,
  ];
}

/// The guides in the language the Community content is shown in.
final guideLibraryProvider = FutureProvider<GuideLibrary>((ref) async {
  final repo = ref.watch(guidesRepositoryProvider);
  final language = ref.watch(communityLanguageProvider);
  final categories = await repo.fetchCategories();
  final guides = await repo.fetchGuides(language);
  return GuideLibrary(categories: categories, guides: guides);
}, retry: noRetry);
