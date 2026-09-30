import 'package:flutter/material.dart';

import 'bundled_guides.dart';

/// The closing line every guide carries.
const guideDisclaimer =
    'This guide is general guidance and not a substitute for advice from your veterinarian.';

/// A shelf of the guides library.
class GuideCategory {
  const GuideCategory({required this.id, required this.name, required this.icon});

  final String id;
  final String name;
  final IconData icon;
}

/// One headed part of a [Guide]: paragraphs, then an optional bullet list,
/// then optional closing paragraphs.
class GuideSection {
  const GuideSection({
    required this.heading,
    this.paragraphs = const [],
    this.bullets = const [],
    this.after = const [],
  });

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;

  /// Paragraphs shown after the bullet list.
  final List<String> after;

  Iterable<String> get _allText => [heading, ...paragraphs, ...bullets, ...after];
}

/// A short reference article.
class Guide {
  const Guide({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.intro,
    required this.sections,
  });

  final String id;
  final String categoryId;
  final String title;

  /// One line for the list card.
  final String summary;

  /// Opening paragraph of the reader.
  final String intro;
  final List<GuideSection> sections;

  Iterable<String> get _allText => [title, summary, intro, for (final s in sections) ...s._allText];

  /// Minutes to read at an unhurried 200 words a minute, at least one.
  int get readingMinutes {
    final words = _allText.fold<int>(0, (sum, text) => sum + text.trim().split(RegExp(r'\s+')).length);
    return (words / 200).ceil().clamp(1, 60);
  }

  /// Whether every word of [query] appears somewhere in the guide.
  bool matches(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final haystack = _allText.join(' ').toLowerCase();
    return words.every(haystack.contains);
  }
}

/// The guides library. Version 1 ships the guides inside the app (see
/// [BundledGuidesRepository]); the interface leaves room for a server.
abstract class GuidesRepository {
  /// Categories in display order.
  Future<List<GuideCategory>> fetchCategories();

  /// All guides, grouped in category order.
  Future<List<Guide>> fetchGuides();
}

/// Guides compiled into the app: available offline, no database table.
class BundledGuidesRepository implements GuidesRepository {
  const BundledGuidesRepository();

  @override
  Future<List<GuideCategory>> fetchCategories() async => bundledGuideCategories;

  @override
  Future<List<Guide>> fetchGuides() async => bundledGuides;
}
