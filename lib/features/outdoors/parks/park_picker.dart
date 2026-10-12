import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../services/findvet/data/location_service.dart';
import '../../../services/outdoors/data/park_area.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../outdoors_words.dart';
import '../widgets/park_widgets.dart';
import 'park_area_picker.dart';

/// The park a form chose (meetups: "Where? A park from the list").
class PickedPark {
  const PickedPark({
    required this.id,
    required this.displayName,
    required this.tags,
    required this.park,
  });

  final String id;

  /// "Dog park · Ahuza, Ra'anana", in the app's language.
  final String displayName;

  /// What the park is known to have.
  final List<ParkDetail> tags;
  final DogPark park;
}

/// Lets the owner choose a park: "My parks" first, then the area's parks
/// nearest first, as on the list. Returns `null` when they go back.
Future<PickedPark?> pickPark(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<PickedPark>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ParkPickerScreen(),
      ),
    );

class ParkPickerScreen extends ConsumerWidget {
  const ParkPickerScreen({super.key});

  static const screenKey = Key('park-picker');

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: ParkCapabilities.view,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final l10n = context.outdoorsL10n;
        final language = languageOf(context);
        final state = ref.watch(parksControllerProvider);
        final where = ref.watch(outsideAreaProvider);
        final controller = ref.read(parksControllerProvider.notifier);
        final listing = ref.watch(parksListingProvider);
        final area = state.area;

        void choose(DogPark park) => Navigator.of(context).pop(
          PickedPark(
            id: park.id,
            displayName: l10n.parkFullName(park, language),
            tags: park.has,
            park: park,
          ),
        );

        return Scaffold(
          key: screenKey,
          body: Column(
            children: [
              CoralHeader(title: l10n.pickParkTitle, showBack: true),
              Expanded(
                child: ListView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.screen,
                    14,
                    AppSpacing.screen,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    if (area == null)
                      ParkAreaPicker(
                        locating: where.locating,
                        problem: where.problem,
                        onNearMe: controller.useMyLocation,
                        onOpenSettings: () => ref
                            .read(locationServiceProvider)
                            .openSettings(LocationOutcome.deniedForever),
                        onCity: controller.chooseCity,
                      )
                    else ...[
                      ParkAreaBar(
                        area: area,
                        // Outside's one area: changed in place, as from
                        // the tab's header.
                        onChange: () => openOutsideAreaSheet(context),
                        onRadius: controller.setRadius,
                      ),
                      const SizedBox(height: 12),
                      if (listing?.value case final value?)
                        for (final item in value.all)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ParkCard(
                              listing: item,
                              showDistance: area is NearMeArea,
                              onTap: () => choose(item.park),
                              trailing: const AppIcon(
                                Icons.chevron_right_rounded,
                                color: AppColors.brown,
                              ),
                            ),
                          )
                      else if (listing?.hasError ?? false)
                        Text(l10n.loadFailed, style: AppText.body)
                      else
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
