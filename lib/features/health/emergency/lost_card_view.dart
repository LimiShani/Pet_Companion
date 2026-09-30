import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../data/health_models.dart';

/// The few fixed words of a lost card, in the card's own language. The
/// card is read by neighbours, so it does not follow the app's language:
/// its words are Health's strings (`lostCard...` in the strings files) of
/// the language chosen for the card, whatever the app is showing.
class LostCardWords {
  const LostCardWords._({
    required this.rightToLeft,
    required this.heading,
    required this.area,
    required this.when,
    required this.microchip,
    required this.microchipped,
    required this.call,
    required this.footer,
    required this.around,
  });

  factory LostCardWords.of(LostCardLanguage language) {
    final l10n = lookupHealthL10n(lostCardLocale(language));
    return LostCardWords._(
      rightToLeft: language == LostCardLanguage.hebrew,
      heading: l10n.lostCardHeading,
      area: l10n.lostCardArea,
      when: l10n.lostCardWhen,
      microchip: l10n.lostCardMicrochip,
      microchipped: l10n.lostCardMicrochipped,
      call: l10n.lostCardCall,
      footer: l10n.lostCardFooter,
      around: l10n.lostCardAround,
    );
  }

  final bool rightToLeft;
  final String Function(String name) heading;
  final String area;
  final String when;
  final String microchip;
  final String microchipped;
  final String Function(String name) call;
  final String footer;
  final String Function(String date, String time) around;
}

/// The locale of the card's own language.
Locale lostCardLocale(LostCardLanguage language) => Locale(language.code);

/// What the language switch of the lost-pet page calls [language]: its name
/// in its own letters (עברית, English), on every screen.
String lostCardLanguageName(LostCardLanguage language) => nativeLanguageName(lostCardLocale(language));

/// Everything that is on one lost card. Plain text, so it can be checked
/// without drawing anything.
class LostCardContent {
  const LostCardContent({
    required this.language,
    required this.petName,
    this.description = '',
    this.area = '',
    this.lastSeenAt,
    this.microchipped = false,
    this.phone = '',
    this.extra = '',
  });

  final LostCardLanguage language;
  final String petName;
  final String description;

  /// A general area, as the owner typed it.
  final String area;
  final DateTime? lastSeenAt;

  /// The card only ever says that there is a chip, never its number.
  final bool microchipped;

  /// Empty until the owner has confirmed the number for the card.
  final String phone;
  final String extra;

  LostCardWords get words => LostCardWords.of(language);

  String get heading => words.heading(petName);

  /// "10.06.25, around 16:30", or `null` when no time was given.
  String? get whenText {
    final at = lastSeenAt;
    final format = AppFormat.forLocale(lostCardLocale(language));
    return at == null ? null : words.around(format.date(at), format.time(at));
  }

  /// Label and value rows under the description.
  List<(String, String)> get facts => [
    if (area.trim().isNotEmpty) (words.area, area.trim()),
    if (whenText != null) (words.when, whenText!),
    if (microchipped) (words.microchip, words.microchipped),
  ];

  /// Every piece of text on the card, in reading order.
  List<String> get allText => [
    heading,
    if (description.trim().isNotEmpty) description.trim(),
    if (extra.trim().isNotEmpty) extra.trim(),
    for (final fact in facts) ...[fact.$1, fact.$2],
    if (phone.trim().isNotEmpty) ...[words.call(petName), phone.trim()],
    words.footer,
  ];
}

/// Whether [area] reads like an exact address (it names a house number)
/// rather than a neighbourhood.
bool looksLikeExactAddress(String area) => RegExp(r'\d').hasMatch(area);

/// "kelly-lost-card": a file name made from the pet's name.
String lostCardFileName(String petName, String extension) {
  final slug = petName.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return '${slug.isEmpty ? 'pet' : slug}-lost-card.$extension';
}

/// The card as it is shared: a heading, the photo when there is one, the
/// description, where and when, and the phone number to call.
class LostCardView extends StatelessWidget {
  const LostCardView({super.key, required this.content, this.photo});

  final LostCardContent content;

  /// Left out entirely when the pet has no photo.
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final words = content.words;
    final picture = photo;
    final cardDirection = words.rightToLeft ? TextDirection.rtl : TextDirection.ltr;
    // What the owner typed keeps its own direction on the card.
    TextDirection typed(String text) => directionOfText(text, fallback: cardDirection);
    const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.4);
    const small = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brown);

    return Directionality(
      textDirection: cardDirection,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE7D9B5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              color: AppColors.coralDark,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Text(
                  content.heading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.white),
                ),
              ),
            ),
            if (picture != null)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image(
                  image: picture,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  // A photo that cannot be shown leaves the space quiet.
                  errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.sage),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (content.description.trim().isNotEmpty)
                    Text(content.description.trim(), style: body, textDirection: typed(content.description.trim())),
                  if (content.extra.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 4),
                      child: Text(content.extra.trim(), style: body, textDirection: typed(content.extra.trim())),
                    ),
                  for (final (label, value) in content.facts)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 52),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(top: 2),
                              child: Text(label, style: small),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(value, style: body.copyWith(fontSize: 14), textDirection: typed(value)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (content.phone.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(12),
                    child: Column(
                      children: [
                        Text(
                          words.call(content.petName),
                          textAlign: TextAlign.center,
                          style: small.copyWith(color: AppColors.ink),
                        ),
                        // A phone number always reads left to right.
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            content.phone.trim(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 18, 14),
              child: Text(words.footer, textAlign: TextAlign.center, style: small.copyWith(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
