import 'dart:ui' show TextDirection;

import 'package:intl/intl.dart' show Bidi;

// Helpers for text that mixes Hebrew with numbers, Latin words and what
// people typed. The marks used here are invisible and take no room.
//
// Why they are needed: inside a right-to-left line, a phone number such as
// "+972 3 555 0142" is laid out group by group from the right and reads
// "0142 555 3 972+", and "-40%" becomes "40%-".

const _leftToRightIsolate = '\u{2066}';
const _firstStrongIsolate = '\u{2068}';
const _popIsolate = '\u{2069}';

/// [text] kept left-to-right as one unit, wherever it is placed. For phone
/// numbers, e-mail and web addresses, percentages with a sign, time ranges,
/// microchip numbers.
String ltr(String text) => text.isEmpty ? text : '$_leftToRightIsolate$text$_popIsolate';

/// [text] kept as one unit in its own direction, so a name or a sentence
/// somebody typed cannot reorder the line around it. Use it when putting
/// a value into a sentence by hand; the Hebrew strings files already wrap
/// their own placeholders this way.
String isolate(String text) => text.isEmpty ? text : '$_firstStrongIsolate$text$_popIsolate';

/// [text] without the marks added by [ltr] and [isolate] (for copying to
/// the clipboard, dialling, or comparing).
String stripBidiMarks(String text) => text.replaceAll(RegExp('[\u{2066}-\u{2069}\u{200E}\u{200F}]'), '');

/// The direction of something a person wrote (a post, a chat message, a
/// note): that of its first real letter, or [fallback] when it has none
/// (only digits, emoji or punctuation). Give it to `Text.textDirection`,
/// so an English post stays left-aligned on a Hebrew screen and the other
/// way round.
TextDirection directionOfText(String text, {required TextDirection fallback}) {
  if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
  if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
  return fallback;
}
