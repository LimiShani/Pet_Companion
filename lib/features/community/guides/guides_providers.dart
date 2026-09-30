import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_providers.dart';
import '../data/guides_repository.dart';
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

  /// Guides in [categoryId] (all when `null`) that match [query].
  List<Guide> search({String query = '', String? categoryId}) => [
        for (final g in guides)
          if ((categoryId == null || g.categoryId == categoryId) && g.matches(query)) g,
      ];
}

final guideLibraryProvider = FutureProvider<GuideLibrary>(
  (ref) async {
    final repo = ref.watch(guidesRepositoryProvider);
    final categories = await repo.fetchCategories();
    final guides = await repo.fetchGuides();
    return GuideLibrary(categories: categories, guides: guides);
  },
  retry: noRetry,
);
