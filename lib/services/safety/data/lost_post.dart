import 'package:intl/intl.dart';

/// The words of a Lost mode post, as `safety_private.post_body` (0034)
/// writes them on the server: the preview of step 2 and the demo's fake
/// post say exactly what the feed will. No phone number, no address:
/// sightings come as comments.
///
/// [language] is 'he' or 'en' (the lost card's language); [species] as in
/// `pets.species`; [looks] is the lost card's description; [place] the
/// public place and [area] the town's name in [language].
String lostPostBody({
  required String language,
  required String name,
  required String species,
  String? breed,
  String looks = '',
  required DateTime seenAt,
  String place = '',
  String area = '',
  String note = '',
}) {
  final fsi = String.fromCharCode(0x2068);
  final pdi = String.fromCharCode(0x2069);
  final he = language == 'he';
  final kind = switch (species) {
    'dog' => he ? 'כלב' : 'Dog',
    'cat' => he ? 'חתול' : 'Cat',
    'bird' => he ? 'ציפור' : 'Bird',
    'rabbit' => he ? 'ארנב' : 'Rabbit',
    'reptile' => he ? 'זוחל' : 'Reptile',
    _ => null,
  };
  final facts = [?kind, if ((breed ?? '').trim().isNotEmpty) breed!.trim()]
      .join(' · ');
  final where = [
    if (place.trim().isNotEmpty) place.trim(),
    if (area.trim().isNotEmpty) area.trim(),
  ].join(', ');
  final seen = DateFormat('dd.MM HH:mm').format(seenAt);
  final lines = <String>[
    he ? 'מחפשים את $fsi$name$pdi' : '$name is missing',
    if (facts.isNotEmpty) facts,
    if (looks.trim().isNotEmpty) looks.trim(),
    he
        ? 'הפעם האחרונה שראינו: $seen${where.isEmpty ? '' : ' · $fsi$where$pdi'}'
        : 'Last seen $seen${where.isEmpty ? '' : ' · $where'}',
    if (note.trim().isNotEmpty) note.trim(),
    he
        ? 'כל מראה של $fsi$name$pdi עוזר: אפשר לכתוב בתגובה איפה ומתי.'
        : 'Seen $name? Please comment with where and when.',
  ];
  final body = lines.join('\n');
  return body.length > 2000 ? body.substring(0, 2000) : body;
}
