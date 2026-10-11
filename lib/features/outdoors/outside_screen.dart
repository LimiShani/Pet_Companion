import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/access_provider.dart';
import '../../access/feature_gate.dart';
import '../../l10n/l10n.dart';
import '../../services/outdoors/state/parks_providers.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import 'outside_section.dart';

/// The Outside tab: dog parks, and walk and play partners from the meetups
/// module, switched from the header ("Partners | Parks"). Partners shows
/// first; an account without parks sees Partners alone, with no switch.
class OutsideScreen extends ConsumerWidget {
  const OutsideScreen({super.key});

  /// The capability that shows the tab: either side of Outside.
  static const capability =
      '${ParkCapabilities.view}|community.meetups.view';

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
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: l10n.sectionOutside,
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
