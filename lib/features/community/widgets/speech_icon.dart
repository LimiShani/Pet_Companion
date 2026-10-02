import 'package:flutter/material.dart';

import '../../../widgets/app_icon.dart';
import '../../../widgets/directional_icon.dart';

/// The icons of the Community tab that point somewhere but which Flutter
/// does not mirror by itself: the speech bubbles, whose tail is on the
/// side the speaker is on.
const _pointing = [
  Icons.chat_bubble_rounded,
  Icons.chat_bubble_outline_rounded,
  Icons.forum_rounded,
];

/// [icon] as the Community tab draws it: a speech bubble is mirrored on a
/// right-to-left screen, so its tail stays on the side the line starts at;
/// every other icon is left to Flutter, which already mirrors the ones
/// that need it (the chevron, the send arrow, "open in a new window").
class DirectionalCommunityIcon extends StatelessWidget {
  const DirectionalCommunityIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _pointing.contains(icon)
        ? MirroredIcon(icon, size: size, color: color)
        : AppIcon(icon, size: size, color: color);
  }
}
