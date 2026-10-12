import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart'
    show kHealthTapTarget, showHealthSheet;
import '../../../services/findvet/data/location_service.dart';
import '../../../services/findvet/regions/regions.dart';
import '../../../services/outdoors/data/park_area.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../outdoors_words.dart';

/// "Where should we look?": the phone's location (asked for only on the
/// tap, after saying why) or a city from the bundled list. No server call.
class ParkAreaPicker extends StatefulWidget {
  const ParkAreaPicker({
    super.key,
    required this.locating,
    required this.problem,
    required this.onNearMe,
    required this.onOpenSettings,
    required this.onCity,
  });

  static const nearMeKey = Key('parks-near-me');
  static const cityFieldKey = Key('parks-city-field');
  static const openSettingsKey = Key('parks-open-settings');
  static Key cityKey(String code) => Key('parks-city-$code');

  final bool locating;
  final AreaProblem? problem;
  final VoidCallback onNearMe;
  final VoidCallback onOpenSettings;
  final ValueChanged<Locality> onCity;

  @override
  State<ParkAreaPicker> createState() => _ParkAreaPickerState();
}

class _ParkAreaPickerState extends State<ParkAreaPicker> {
  final _query = TextEditingController();
  List<Locality> _matches = const [];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _suggest(String text) => setState(() {
    _matches = [
      for (final region in vetRegions) ...region.findLocalities(text),
    ];
  });

  String? _problemText(OutdoorsL10n l10n) => switch (widget.problem) {
    null => null,
    AreaProblem.denied => l10n.problemDenied,
    AreaProblem.deniedForever => l10n.problemDeniedForever,
    AreaProblem.serviceOff => l10n.problemServiceOff,
    AreaProblem.unavailable => l10n.problemUnavailable,
    AreaProblem.outsideRegion => l10n.problemOutsideRegion,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final problem = _problemText(l10n);
    final canOpenSettings =
        widget.problem == AreaProblem.deniedForever ||
        widget.problem == AreaProblem.serviceOff;
    final typed = _query.text.trim().length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.areaQuestion,
            style: AppText.cardTitle.copyWith(fontSize: 19),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(top: 2, end: 8),
              child: AppIcon(
                Icons.lock_outline_rounded,
                size: 20,
                color: AppColors.brown,
              ),
            ),
            Expanded(
              child: Text(
                l10n.locationWhy,
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: ParkAreaPicker.nearMeKey,
          onPressed: widget.locating ? null : widget.onNearMe,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(kHealthTapTarget),
          ),
          icon: widget.locating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const AppIcon(Icons.my_location_rounded),
          label: Text(widget.locating ? l10n.locating : l10n.nearMe),
        ),
        if (problem != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(problem, style: AppText.body),
                  if (canOpenSettings)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: ParkAreaPicker.openSettingsKey,
                        onPressed: widget.onOpenSettings,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            kHealthTapTarget,
                            kHealthTapTarget,
                          ),
                        ),
                        child: Text(l10n.openSettings),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          l10n.orPickCity,
          style: AppText.label.copyWith(color: AppColors.brown),
        ),
        const SizedBox(height: 6),
        TextField(
          key: ParkAreaPicker.cityFieldKey,
          controller: _query,
          textInputAction: TextInputAction.search,
          onChanged: _suggest,
          onSubmitted: (_) {
            if (_matches.length == 1) widget.onCity(_matches.single);
          },
          decoration: InputDecoration(
            hintText: l10n.cityHint,
            labelText: l10n.cityHint,
            prefixIcon: const AppIcon(Icons.search_rounded),
          ),
        ),
        if (typed && _matches.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(l10n.noCityMatch, style: AppText.body),
            ),
          ),
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final locality in _matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: ParkAreaPicker.cityKey(locality.code),
                  minTileHeight: kHealthTapTarget,
                  leading: const AppIcon(
                    Icons.place_outlined,
                    color: AppColors.coralDark,
                  ),
                  title: Text(
                    locality.nameIn(language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => widget.onCity(locality),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Changes Outside's one area (the chip in the tab's header, a park
/// picker's "Change"): the same "Near me" or a city as the first time. The
/// choice applies to the parks and the partners alike.
Future<void> openOutsideAreaSheet(BuildContext context) =>
    showHealthSheet<void>(context, const OutsideAreaSheet());

class OutsideAreaSheet extends ConsumerWidget {
  const OutsideAreaSheet({super.key});

  static const sheetKey = Key('outside-area-sheet');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(outsideAreaProvider);
    final controller = ref.read(outsideAreaProvider.notifier);
    return Padding(
      key: sheetKey,
      padding: const EdgeInsets.only(top: 16),
      child: ParkAreaPicker(
        locating: state.locating,
        problem: state.problem,
        onNearMe: () async {
          await controller.useMyLocation();
          if (context.mounted &&
              ref.read(outsideAreaProvider).problem == null) {
            Navigator.of(context).pop();
          }
        },
        onOpenSettings: () => ref
            .read(locationServiceProvider)
            .openSettings(
              state.problem == AreaProblem.serviceOff
                  ? LocationOutcome.serviceOff
                  : LocationOutcome.deniedForever,
            ),
        onCity: (city) {
          controller.chooseCity(city);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// "Up to 10 km ▾": the radius of Outside's area as one chip; its menu
/// offers the others ("City only" only around a city). The parks' filter
/// row and the partners' row show it.
class ParkRadiusChip extends StatelessWidget {
  const ParkRadiusChip({
    super.key,
    required this.area,
    required this.onRadius,
    this.optionKey = ParkAreaBar.radiusKey,
  });

  final ParkArea area;
  final ValueChanged<ParkRadius> onRadius;

  /// The key of each option in the menu, for tests.
  final Key Function(ParkRadius radius) optionKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final options = [
      if (area is CityArea) ParkRadius.cityOnly,
      ParkRadius.km10,
      ParkRadius.km25,
    ];
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            key: optionKey(option),
            onPressed: () => onRadius(option),
            leadingIcon: option == area.radius
                ? const AppIcon(Icons.check_rounded, size: 20)
                : const SizedBox(width: 20),
            child: Text(l10n.radius(option)),
          ),
      ],
      builder: (context, menu, _) => ActionChip(
        backgroundColor: AppColors.yellow,
        side: BorderSide.none,
        // Snug, so it shares a row on a 320 px phone.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        labelPadding: const EdgeInsetsDirectional.only(start: 6, end: 2),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.radius(area.radius),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 2),
            const AppIcon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

/// "Near me · Ra'anana   Change" with the radius chips under it (a park
/// picker; the Outside tab has its area in the header).
class ParkAreaBar extends StatelessWidget {
  const ParkAreaBar({
    super.key,
    required this.area,
    required this.onChange,
    required this.onRadius,
    this.showRadius = true,
  });

  static const changeKey = Key('parks-change-area');
  static Key radiusKey(ParkRadius radius) => Key('parks-radius-${radius.name}');

  final ParkArea area;
  final VoidCallback onChange;
  final ValueChanged<ParkRadius> onRadius;

  /// `false` leaves the radius chips out (the partners board has them in
  /// its filters).
  final bool showRadius;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final area = this.area;
    final (IconData icon, String place) = switch (area) {
      NearMeArea(:final nearest) => (
        Icons.my_location_rounded,
        nearest == null
            ? l10n.areaNearMe
            : l10n.areaNearMeIn(nearest.nameIn(language)),
      ),
      CityArea(:final locality) => (
        Icons.place_rounded,
        locality.nameIn(language),
      ),
    };
    final radii = [
      if (area is CityArea) ParkRadius.cityOnly,
      ParkRadius.km10,
      ParkRadius.km25,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 20, color: AppColors.coralDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  place,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Semantics(
                button: true,
                label: l10n.changeAreaLabel,
                excludeSemantics: true,
                child: TextButton(
                  key: changeKey,
                  onPressed: onChange,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
                  ),
                  child: Text(l10n.changeArea),
                ),
              ),
            ],
          ),
        ),
        if (area is NearMeArea && area.isApproximate)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, top: 4),
            child: Text(
              l10n.approximateLocation(((area.accuracyM ?? 0) / 1000).ceil()),
              style: AppText.secondary.copyWith(color: AppColors.ink),
            ),
          ),
        if (showRadius) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final radius in radii)
                ChoiceChip(
                  key: radiusKey(radius),
                  label: Text(l10n.radius(radius)),
                  selected: area.radius == radius,
                  showCheckmark: false,
                  onSelected: (_) => onRadius(radius),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
