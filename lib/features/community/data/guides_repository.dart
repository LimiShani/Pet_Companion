import 'package:flutter/material.dart';

import 'audience.dart';
import 'community_language.dart';
import 'guides/guide_catalog.dart';
import 'guides/guides_en.dart';
import 'guides/guides_he.dart';

/// A shelf of the guides library.
class GuideCategory {
  const GuideCategory({required this.id, required this.name, required this.icon});

  final String id;

  /// The shelf's name as stored (English for the shelves the app ships
  /// with). The screen shows the shelves it knows by [id] in its own
  /// language (`CommunityWords.categoryName`).
  final String name;
  final IconData icon;
}

/// A calendar day, as a constant (a `DateTime` cannot be one), so the
/// bundled guides stay compile-time constants.
class GuideDate {
  const GuideDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  DateTime toDateTime() => DateTime(year, month, day);

  bool isAfter(GuideDate other) => toDateTime().isAfter(other.toDateTime());
}

/// Who wrote a guide, and in what capacity. Must be true: no invented
/// people and no qualifications the writers do not hold.
class GuideAuthor {
  const GuideAuthor({required this.name, required this.role});

  /// e.g. "PetLoop team".
  final String name;

  /// What they are, and are not, e.g. "App content team, writing with an
  /// AI assistant. Not veterinarians or trainers."
  final String role;
}

/// A professional's review of one guide text. Record one only for a real
/// person who read that text and agreed to be named: all three fields are
/// required.
class GuideReview {
  const GuideReview({required this.reviewerName, required this.reviewerRole, required this.reviewedAt});

  /// The reviewer's full name.
  final String reviewerName;

  /// Their profession, e.g. "Veterinarian".
  final String reviewerRole;

  /// The day they reviewed the text.
  final GuideDate reviewedAt;
}

/// A published source a guide was written or revised against.
class GuideSource {
  const GuideSource({required this.title, this.publisher, this.url});

  final String title;
  final String? publisher;

  /// Opens in the browser when set.
  final String? url;
}

/// One headed part of a guide: paragraphs, then an optional bullet list,
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

/// A guide's text in one language, with where that text comes from: who
/// wrote it, when it last changed, who reviewed it and what it cites.
class GuideText {
  const GuideText({
    required this.title,
    required this.summary,
    required this.intro,
    required this.sections,
    required this.author,
    required this.updatedAt,
    this.review,
    this.sources = const [],
  });

  final String title;

  /// One line for the list card.
  final String summary;

  /// Opening paragraph of the reader.
  final String intro;
  final List<GuideSection> sections;

  final GuideAuthor author;

  /// The day this text last changed.
  final GuideDate updatedAt;

  /// The review as recorded. The app shows [currentReview].
  final GuideReview? review;
  final List<GuideSource> sources;

  /// The review, while it still applies. A review covers the text as the
  /// reviewer read it, so it stops counting once the text has changed after
  /// the review date, until the guide is reviewed again.
  GuideReview? get currentReview {
    final recorded = review;
    if (recorded == null || updatedAt.isAfter(recorded.reviewedAt)) return null;
    return recorded;
  }

  Iterable<String> get _allText => [title, summary, intro, for (final s in sections) ...s._allText];
}

/// The part of a guide that is the same in every language.
class GuideRecord {
  const GuideRecord({required this.id, required this.categoryId, required this.audience});

  final String id;
  final String categoryId;
  final Audience audience;
}

/// A short reference article, in the language it is shown in.
class Guide {
  const Guide({required this.record, required this.text, required this.language, required this.translated});

  final GuideRecord record;
  final GuideText text;

  /// The language [text] is written in.
  final ContentLanguage language;

  /// Whether [text] is in the language that was asked for. When it is not,
  /// the guide is shown in English with an "English only" tag.
  final bool translated;

  String get id => record.id;
  String get categoryId => record.categoryId;
  Audience get audience => record.audience;

  String get title => text.title;
  String get summary => text.summary;
  String get intro => text.intro;
  List<GuideSection> get sections => text.sections;
  GuideAuthor get author => text.author;
  DateTime get updatedAt => text.updatedAt.toDateTime();
  List<GuideSource> get sources => text.sources;

  /// The review that applies to this text, if any (see
  /// [GuideText.currentReview]).
  GuideReview? get review => text.currentReview;

  /// Minutes to read at an unhurried 200 words a minute, at least one.
  int get readingMinutes {
    final words = text._allText.fold<int>(0, (sum, part) => sum + part.trim().split(RegExp(r'\s+')).length);
    return (words / 200).ceil().clamp(1, 60);
  }

  /// Whether every word of [query] appears somewhere in the guide.
  bool matches(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final haystack = text._allText.join(' ').toLowerCase();
    return words.every(haystack.contains);
  }
}

/// The guides library. Version 1 ships the guides inside the app (see
/// [BundledGuidesRepository]); the interface leaves room for a server.
abstract class GuidesRepository {
  /// Categories in display order.
  Future<List<GuideCategory>> fetchCategories();

  /// All guides, grouped in category order, each in [language] where it is
  /// translated and in English where it is not.
  Future<List<Guide>> fetchGuides(ContentLanguage language);
}

/// Guides compiled into the app: available offline, no database table.
///
/// One [GuideRecord] per guide, and one [GuideText] per guide and language
/// (`data/guides/guides_en.dart`, `guides_he.dart`).
class BundledGuidesRepository implements GuidesRepository {
  const BundledGuidesRepository({
    this.categories = guideCategories,
    this.records = guideRecords,
    this.texts = const {ContentLanguage.en: guidesEn, ContentLanguage.he: guidesHe},
  });

  final List<GuideCategory> categories;
  final List<GuideRecord> records;

  /// The guide texts by language, then by guide id.
  final Map<ContentLanguage, Map<String, GuideText>> texts;

  @override
  Future<List<GuideCategory>> fetchCategories() async => categories;

  @override
  Future<List<Guide>> fetchGuides(ContentLanguage language) async {
    final guides = <Guide>[];
    for (final record in records) {
      final own = texts[language]?[record.id];
      final text = own ?? texts[ContentLanguage.en]?[record.id];
      // Every guide has English text (a test holds the catalog to that).
      if (text == null) continue;
      guides.add(Guide(
        record: record,
        text: text,
        language: own != null ? language : ContentLanguage.en,
        translated: own != null,
      ));
    }
    return guides;
  }
}
