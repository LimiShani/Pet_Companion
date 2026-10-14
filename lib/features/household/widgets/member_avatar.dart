import 'package:flutter/material.dart';

import '../../../services/household/data/household_models.dart';
import '../../../theme/app_colors.dart';

/// A member's letter on a disc whose colour comes from their account, so
/// the same person has the same colour on every screen.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 40,
    this.ring = false,
  });

  final HouseholdMember member;
  final double size;

  /// A white ring, for avatars that overlap.
  final bool ring;

  static const _colors = [
    Color(0xFFC4502F),
    Color(0xFF7E9A5A),
    Color(0xFFB07A2A),
    Color(0xFF6E8DA6),
    Color(0xFF9B6B8E),
    Color(0xFF8A7461),
  ];

  /// The disc's colour for [userId].
  static Color colorOf(String userId) {
    var hash = 0;
    for (final unit in userId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _colors[hash % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorOf(member.userId),
        shape: BoxShape.circle,
        border: ring ? Border.all(color: AppColors.white, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: ExcludeSemantics(
        child: Text(
          member.initial,
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Up to three overlapping [MemberAvatar]s, then "+n".
class StackedAvatars extends StatelessWidget {
  const StackedAvatars({super.key, required this.members, this.size = 26});

  final List<HouseholdMember> members;
  final double size;

  static const shown = 3;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(shown).toList();
    final more = members.length - visible.length;
    final step = size * 0.68;
    final width = size + step * (visible.length - 1 + (more > 0 ? 1 : 0));
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            PositionedDirectional(
              start: step * i,
              child: MemberAvatar(member: visible[i], size: size, ring: true),
            ),
          if (more > 0)
            PositionedDirectional(
              start: step * visible.length,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: ExcludeSemantics(
                  child: Text(
                    '+$more',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.38,
                      height: 1,
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
