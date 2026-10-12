import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../access/access_provider.dart';
import '../../l10n/l10n.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../services/outdoors/state/parks_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import 'parks/parks_view.dart';

/// The slot the meetups feature fills with its Partners side. Until a
/// module registers it, Partners shows a friendly "coming soon".
const outsidePartnersSlot = 'outside-partners';

/// The slot the meetups feature fills with the floating "+ New ad" button
/// the Outside tab shows while Partners is on screen.
const outsideNewAdSlot = 'outside-new-ad';

/// Whether an installed module the account may use fills slot [name].
bool slotAvailable(WidgetRef ref, String name) {
  for (final module in ref.watch(featureModulesProvider)) {
    final slot = module.slots[name];
    if (slot != null && ref.watch(capabilityProvider(slot.capability))) {
      return true;
    }
  }
  return false;
}

/// The body of the Outside tab: the parks or the partners, whichever the
/// header's "Partners | Parks" switch (see `OutsideScreen`) chose. Partners
/// shows first once the meetups module fills it; an account without parks
/// sees Partners alone.
class OutsideSection extends ConsumerWidget {
  const OutsideSection({super.key});

  static const sectionKey = Key('outside-section');

  /// The segments of the switch in the tab's header, for tests.
  static const partnersKey = Key('outside-switch-partners');
  static const parksKey = Key('outside-switch-parks');
  static const partnersSoonKey = Key('outside-partners-soon');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(outsideViewProvider);
    final controller = ref.read(outsideViewProvider.notifier);
    if (!ref.watch(capabilityProvider(ParkCapabilities.view))) {
      return KeyedSubtree(
        key: sectionKey,
        child: featureSlot(outsidePartnersSlot, ''),
      );
    }
    return OutdoorsKeeper(
      child: KeyedSubtree(
        key: sectionKey,
        child: view == OutsideView.parks
            ? const ParksView()
            : slotAvailable(ref, outsidePartnersSlot)
            ? featureSlot(outsidePartnersSlot, '')
            : _PartnersSoon(
                onShowParks: () => controller.show(OutsideView.parks),
              ),
      ),
    );
  }
}

class _PartnersSoon extends StatelessWidget {
  const _PartnersSoon({required this.onShowParks});

  final VoidCallback onShowParks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    return ListView(
      key: OutsideSection.partnersSoonKey,
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppIcon(
                Icons.directions_walk_rounded,
                size: 40,
                color: AppColors.ink,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.partnersSoonTitle,
                textAlign: TextAlign.center,
                style: AppText.cardTitle,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.partnersSoonBody,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onShowParks,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(kHealthTapTarget),
                ),
                icon: const AppIcon(Icons.park_rounded),
                label: Text(l10n.partnersShowParks),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Keeps the parks lists active while the park page, the suggestion form or
/// the review page covers them, for the reason given on `CommunityKeeper`:
/// Riverpod 3 pauses covered subscriptions and would flush them in the
/// middle of a build when the route comes back.
class OutdoorsKeeper extends StatefulWidget {
  const OutdoorsKeeper({super.key, required this.child});

  final Widget child;

  @override
  State<OutdoorsKeeper> createState() => _OutdoorsKeeperState();
}

class _OutdoorsKeeperState extends State<OutdoorsKeeper> {
  ProviderContainer? _container;
  final _subscriptions = <ProviderSubscription<Object?>>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context);
    if (!identical(container, _container)) {
      _container = container;
      _close();
      void keep<T>(ProviderListenable<T> provider) => _subscriptions.add(
        container.listen<T>(provider, (_, _) {}, onError: (_, _) {}),
      );
      keep(outsideAreaProvider);
      keep(parksControllerProvider);
      keep(parkFavoritesProvider);
      keep(savedParksProvider);
      keep(parksListingProvider);
      keep(parkReviewQueueProvider);
      keep(outsideViewProvider);
    }
  }

  void _close() {
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
