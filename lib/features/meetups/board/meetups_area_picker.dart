import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../services/findvet/regions/regions.dart';
import '../../../services/findvet/state/find_vet_providers.dart'
    show AreaProblem;
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../outdoors/outdoors_words.dart';

/// "Where do you go out?": the nearest city to the phone (asked for only on
/// the tap, after saying why, and only to pick the city), or a city from
/// the bundled list. No server call.
class MeetupsAreaPicker extends StatefulWidget {
  const MeetupsAreaPicker({
    super.key,
    required this.locating,
    required this.problem,
    required this.onNearMe,
    required this.onOpenSettings,
    required this.onCity,
    this.title,
  });

  static const nearMeKey = Key('meetups-near-me');
  static const cityFieldKey = Key('meetups-city-field');
  static Key cityKey(String code) => Key('meetups-city-$code');

  final bool locating;
  final AreaProblem? problem;

  /// `null` hides "Near me" (the form's city).
  final VoidCallback? onNearMe;
  final VoidCallback onOpenSettings;
  final ValueChanged<Locality> onCity;

  /// Replaces the question (the form asks only for the city).
  final String? title;

  @override
  State<MeetupsAreaPicker> createState() => _MeetupsAreaPickerState();
}

class _MeetupsAreaPickerState extends State<MeetupsAreaPicker> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.meetupsL10n;
    final outdoors = context.outdoorsL10n;
    final language = languageOf(context);
    final problem = switch (widget.problem) {
      null => null,
      AreaProblem.denied => outdoors.problemDenied,
      AreaProblem.deniedForever => outdoors.problemDeniedForever,
      AreaProblem.serviceOff => outdoors.problemServiceOff,
      AreaProblem.unavailable => outdoors.problemUnavailable,
      AreaProblem.outsideRegion => l10n.problemOutsideRegion,
    };
    final canOpenSettings =
        widget.problem == AreaProblem.deniedForever ||
        widget.problem == AreaProblem.serviceOff;
    final typed = _query.text.trim().length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onNearMe case final onNearMe?) ...[
          Semantics(
            header: true,
            child: Text(
              widget.title ?? l10n.areaQuestion,
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
                  outdoors.locationWhy,
                  style: AppText.body.copyWith(color: AppColors.brown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: MeetupsAreaPicker.nearMeKey,
            onPressed: widget.locating ? null : onNearMe,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            icon: widget.locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const AppIcon(Icons.my_location_rounded),
            label: Text(widget.locating ? outdoors.locating : outdoors.nearMe),
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
                          onPressed: widget.onOpenSettings,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              kHealthTapTarget,
                              kHealthTapTarget,
                            ),
                          ),
                          child: Text(outdoors.openSettings),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            outdoors.orPickCity,
            style: AppText.label.copyWith(color: AppColors.brown),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          key: MeetupsAreaPicker.cityFieldKey,
          controller: _query,
          textInputAction: TextInputAction.search,
          onChanged: _suggest,
          onSubmitted: (_) {
            if (_matches.length == 1) widget.onCity(_matches.single);
          },
          decoration: InputDecoration(
            hintText: outdoors.cityHint,
            labelText: widget.title ?? outdoors.cityHint,
            prefixIcon: const AppIcon(Icons.search_rounded),
          ),
        ),
        if (typed && _matches.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(outdoors.noCityMatch, style: AppText.body),
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
                  key: MeetupsAreaPicker.cityKey(locality.code),
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
