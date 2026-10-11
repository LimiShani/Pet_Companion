import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The app's one segmented control: a pill track with a yellow pill for the
/// selected segment. On the coral header (the `bottom` of a CoralHeader,
/// "Feed | Chat | Guides") the track is translucent dark with white text;
/// on a cream page ([onSurface]) it is a light band with ink text, so the
/// two switches read as the same control.
class CoralSegmentedControl extends StatelessWidget {
  const CoralSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.onSurface = false,
    this.keys,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// True on a cream page, below the header.
  final bool onSurface;

  /// One key per segment, for tests.
  final List<Key>? keys;

  /// The track of the on-page variant.
  static const _surfaceTrack = Color(0xFFFFF3D6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onSurface ? _surfaceTrack : AppColors.onCoralPill,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                child: Material(
                  key: keys?[i],
                  color: i == selectedIndex
                      ? AppColors.yellow
                      : Colors.transparent,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onChanged(i),
                    child: Padding(
                      // Four sections ("Feed | Chat | Outside | Guides")
                      // need the room on a 320 px phone.
                      padding: EdgeInsets.symmetric(
                        horizontal: labels.length > 3 ? 3 : 8,
                        vertical: 9,
                      ),
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: i == selectedIndex || onSurface
                              ? AppColors.ink
                              : AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
