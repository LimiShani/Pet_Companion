import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Settings > About PetLoop: the OpenStreetMap credit the ODbL asks for.
class OsmAboutCredit extends StatelessWidget {
  const OsmAboutCredit({super.key});

  static const creditKey = Key('settings-osm-credit');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 6, top: 8),
      child: Text(
        context.outdoorsL10n.aboutMapData,
        key: creditKey,
        style: AppText.label.copyWith(
          color: AppColors.brown,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
