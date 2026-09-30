import 'package:flutter/widgets.dart';

import '../community_words.dart';

/// Text written by a member (a post, a comment, a chat message, a display
/// name), laid out in its own direction whatever the app's language is, so
/// a Hebrew message reads right to left in an English app and an English
/// one left to right in a Hebrew app. Text with no letters (digits, emoji)
/// follows the screen.
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: contentDirection(context, text),
    );
  }
}
