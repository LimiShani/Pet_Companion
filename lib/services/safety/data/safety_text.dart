import '../../../models/pet.dart';

/// A line of the built-in safety content, in both of the app's languages.
///
/// The safety lists ship inside the app (no backend): their words live in
/// the data files beside this one, not in the strings files, so a vet can
/// review each entry with its sources in one place.
class SafetyText {
  const SafetyText(this.en, this.he);

  final String en;
  final String he;

  /// The text for a language code ('he' gives Hebrew, anything else English).
  String of(String languageCode) => languageCode == 'he' ? he : en;
}

/// Which animal a safety answer is for. Rabbits, reptiles and the rest are
/// [other]: the lists say less about them, and send their owners to the vet.
enum SafetyAnimal {
  dog,
  cat,
  bird,
  other;

  static SafetyAnimal of(PetSpecies species) => switch (species) {
    PetSpecies.dog => SafetyAnimal.dog,
    PetSpecies.cat => SafetyAnimal.cat,
    PetSpecies.bird => SafetyAnimal.bird,
    _ => SafetyAnimal.other,
  };
}

/// A reference a list's content is taken from.
class SafetySource {
  const SafetySource(this.name, this.url);

  final String name;
  final String url;
}

/// [text] reduced for matching a search: lower case, no Hebrew vowel marks
/// or punctuation, Hebrew final letters as their ordinary form (so "שום"
/// matches while typing "שו"), single spaces.
String normalizeSafetySearch(String text) {
  final out = StringBuffer();
  var space = false;
  for (final rune in text.toLowerCase().runes) {
    // Hebrew points and cantillation marks.
    if (rune >= 0x0591 && rune <= 0x05C7) continue;
    var c = rune;
    switch (rune) {
      case 0x05DA: // ך
        c = 0x05DB;
      case 0x05DD: // ם
        c = 0x05DE;
      case 0x05DF: // ן
        c = 0x05E0;
      case 0x05E3: // ף
        c = 0x05E4;
      case 0x05E5: // ץ
        c = 0x05E6;
    }
    final letter =
        (c >= 0x61 && c <= 0x7A) ||
        (c >= 0x30 && c <= 0x39) ||
        (c >= 0x05D0 && c <= 0x05EA) ||
        (c >= 0xE0 && c <= 0xFF);
    if (letter) {
      if (space && out.isNotEmpty) out.write(' ');
      space = false;
      out.writeCharCode(c);
    } else {
      space = true;
    }
  }
  return out.toString();
}
