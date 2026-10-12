import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/access_provider.dart';
import '../../access/feature_gate.dart';
import '../../l10n/l10n.dart';
import '../../platform/feature_ui.dart';
import '../../services/outdoors/data/park_area.dart';
import '../../services/outdoors/state/parks_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import '../../widgets/pet_switcher.dart' show CoralMenuChip;
import 'outdoors_words.dart';
import 'outside_section.dart';
import 'parks/park_area_picker.dart';

/// The Outside tab: dog parks, and walk and play partners from the meetups
/// module, switched from the header ("Partners | Parks"). Partners shows
/// first; an account without parks sees Partners alone, with no switch.
/// Once an area is chosen it is a chip in the header, for both sides; while
/// Partners shows, the meetups module may add a floating "+ New ad".
class OutsideScreen extends ConsumerWidget {
  const OutsideScreen({super.key});

  /// The capability that shows the tab: either side of Outside.
  static const capability =
      '${ParkCapabilities.view}|community.meetups.view';

  static const areaChipKey = Key('outside-area-chip');

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: capability,
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.outdoorsL10n;
    final parks = ref.watch(capabilityProvider(ParkCapabilities.view));
    final view = ref.watch(outsideViewProvider);
    final area = ref.watch(outsideAreaProvider.select((s) => s.area));
    final partnersShown =
        (!parks || view == OutsideView.partners) &&
        slotAvailable(ref, outsidePartnersSlot);
    return Scaffold(
      floatingActionButton:
          partnersShown && slotAvailable(ref, outsideNewAdSlot)
          ? featureSlot(outsideNewAdSlot, '')
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: l10n.sectionOutside,
            actions: [if (area != null) OutsideAreaChip(area: area)],
            bottom: parks
                ? CoralSegmentedControl(
                    labels: [l10n.outsidePartners, l10n.outsideParks],
                    keys: const [
                      OutsideSection.partnersKey,
                      OutsideSection.parksKey,
                    ],
                    selectedIndex: view == OutsideView.partners ? 0 : 1,
                    onChanged: (i) => ref
                        .read(outsideViewProvider.notifier)
                        .show(OutsideView.values[i]),
                  )
                : null,
          ),
          const Expanded(child: OutsideSection()),
        ],
      ),
    );
  }
}

/// "Tel Aviv-Yafo ▾" with a pin, in the header: where Outside looks, for the parks
/// and the partners alike. A tap changes it ([openOutsideAreaSheet]).
class OutsideAreaChip extends StatelessWidget {
  const OutsideAreaChip({super.key, required this.area});

  final ParkArea area;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final area = this.area;
    final (IconData icon, String place) = switch (area) {
      NearMeArea(:final nearest) => (
        Icons.my_location_rounded,
        nearest?.nameIn(language) ?? l10n.areaNearMe,
      ),
      CityArea(:final locality) => (
        Icons.place_rounded,
        locality.nameIn(language),
      ),
    };
    // The tab's title and the account's avatar share the row: the name
    // gets the room they leave (a long one is cut on a small phone), and
    // the title stays whole.
    final title = TextPainter(
      text: TextSpan(text: l10n.sectionOutside, style: AppText.appTitle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final room =
        MediaQuery.sizeOf(context).width -
        2 * AppSpacing.screen -
        (HeaderAvatar.size + 8) -
        (8 + CoralMenuChip.chevronWidth + 8) -
        title.width -
        4;
    title.dispose();
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Semantics(
        button: true,
        label: l10n.areaChipLabel(place),
        onTap: () => openOutsideAreaSheet(context),
        excludeSemantics: true,
        child: CoralMenuChip(
          key: OutsideScreen.areaChipKey,
          leading: SizedBox.square(
            dimension: 24,
            child: Center(
              child: AppIcon(icon, size: 18, color: AppColors.white),
            ),
          ),
          label: place,
          maxLabelWidth: room.clamp(40.0, 140.0),
          onTap: () => openOutsideAreaSheet(context),
        ),
      ),
    );
  }
}
