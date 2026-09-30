import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

/// The direction [text] reads in, going by its first letter: right to left
/// for Hebrew or Arabic, left to right for Latin. `null` when the text has
/// no letters (digits, emoji), so it follows the screen's direction.
TextDirection? directionOfText(String text) {
  if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
  if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
  return null;
}

/// Text written by a member (a post, a comment, a chat message), laid out in
/// its own direction whatever the app's language is, so a Hebrew message
/// reads correctly in an English app and the other way round.
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style, textDirection: directionOfText(text));
  }
}
