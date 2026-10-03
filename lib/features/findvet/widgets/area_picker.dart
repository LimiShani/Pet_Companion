import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../health/widgets/health_widgets.dart' show kHealthTapTarget;
import '../data/vet_models.dart';
import '../findvet_words.dart';
import '../regions/regions.dart';
import '../state/find_vet_providers.dart';

/// "Where should we look?": the phone's location (asked for only on the
/// tap, after saying why) or a place typed by hand. Typing a city name
/// suggests matches from the region's own list at once; Search sends
/// anything else (a street, a postcode) to the server's geocoder.
class AreaPicker extends StatefulWidget {
  const AreaPicker({
    super.key,
    required this.locating,
    required this.problem,
    required this.onUseLocation,
    required this.onOpenSettings,
    required this.onPicked,
    required this.lookUp,
  });

  static const useLocationKey = Key('findvet-use-location');
  static const fieldKey = Key('findvet-place-field');
  static const searchKey = Key('findvet-place-search');
  static const openSettingsKey = Key('findvet-open-settings');

  /// The suggestion for [label].
  static Key matchKey(String label) => Key('findvet-place-$label');

  final bool locating;
  final AreaProblem? problem;
  final VoidCallback onUseLocation;
  final VoidCallback onOpenSettings;
  final ValueChanged<SearchArea> onPicked;

  /// Resolves what the owner typed (local list first, then the server).
  final Future<List<PlaceMatch>> Function(String query) lookUp;

  @override
  State<AreaPicker> createState() => _AreaPickerState();
}

class _AreaPickerState extends State<AreaPicker> {
  final _query = TextEditingController();
  List<PlaceMatch> _matches = const [];
  bool _searching = false;

  /// What went wrong with the last typed search ("not found", "failed").
  String? _message;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// City suggestions while typing, from the bundled lists only.
  void _suggest(String text) {
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _message = null;
      _matches = [
        for (final region in vetRegions)
          for (final locality in region.findLocalities(text))
            PlaceMatch(label: locality.nameIn(language), point: locality.point),
      ];
    });
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.length < 2) return;
    final l10n = context.findVetL10n;
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final matches = await widget.lookUp(text);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _message = matches.isEmpty ? l10n.placeNoMatch : null;
      });
      // One exact answer: use it straight away.
      if (matches.length == 1) _pick(matches.single, AreaSource.typed);
    } catch (_) {
      if (mounted) setState(() => _message = l10n.placeLookupFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(PlaceMatch match, AreaSource source) {
    widget.onPicked(SearchArea(label: match.label, point: match.point, source: source));
  }

  String? _problemText(FindVetL10n l10n) => switch (widget.problem) {
    null => null,
    AreaProblem.denied => l10n.problemDenied,
    AreaProblem.deniedForever => l10n.problemDeniedForever,
    AreaProblem.serviceOff => l10n.problemServiceOff,
    AreaProblem.unavailable => l10n.problemUnavailable,
    AreaProblem.outsideRegion => l10n.problemOutsideRegion,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    final problem = _problemText(l10n);
    final canOpenSettings = widget.problem == AreaProblem.deniedForever || widget.problem == AreaProblem.serviceOff;
    final localMatches = _matches.isNotEmpty && !_searching;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.areaQuestion, style: AppText.cardTitle.copyWith(fontSize: 19)),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(top: 2, end: 8),
              child: AppIcon(Icons.lock_outline_rounded, size: 20, color: AppColors.brown),
            ),
            Expanded(child: Text(l10n.locationWhy, style: AppText.body.copyWith(color: AppColors.brown))),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: AreaPicker.useLocationKey,
          onPressed: widget.locating ? null : widget.onUseLocation,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: widget.locating
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
              : const AppIcon(Icons.my_location_rounded),
          label: Text(widget.locating ? l10n.locating : l10n.useMyLocation),
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
                        key: AreaPicker.openSettingsKey,
                        onPressed: widget.onOpenSettings,
                        style: TextButton.styleFrom(minimumSize: const Size(kHealthTapTarget, kHealthTapTarget)),
                        child: Text(l10n.openSettings),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(l10n.orTypePlace, style: AppText.label.copyWith(color: AppColors.brown)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: AreaPicker.fieldKey,
                controller: _query,
                textInputAction: TextInputAction.search,
                onChanged: _suggest,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(hintText: l10n.placeSearchHint, labelText: l10n.placeSearchHint),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: AreaPicker.searchKey,
              tooltip: l10n.placeSearchButton,
              onPressed: _searching ? null : _search,
              constraints: const BoxConstraints(minWidth: kHealthTapTarget, minHeight: kHealthTapTarget),
              icon: _searching
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const AppIcon(Icons.search_rounded),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(liveRegion: true, child: Text(_message!, style: AppText.body)),
          ),
        if (localMatches) ...[
          const SizedBox(height: 8),
          for (final match in _matches)
            Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: AreaPicker.matchKey(match.label),
                minTileHeight: kHealthTapTarget,
                leading: const AppIcon(Icons.place_outlined, color: AppColors.coralDark),
                title: Text(match.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _pick(match, AreaSource.locality),
              ),
            ),
        ],
      ],
    );
  }
}

/// "Searching near Rehovot · Change", with the warning for a rough fix.
class AreaBar extends StatelessWidget {
  const AreaBar({super.key, required this.area, required this.onChange, this.radiusM});

  static const changeKey = Key('findvet-change-area');

  final SearchArea area;
  final VoidCallback onChange;
  final int? radiusM;

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    final place = area.source == AreaSource.device ? l10n.yourLocation : area.label;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(
                area.source == AreaSource.device ? Icons.my_location_rounded : Icons.place_rounded,
                size: 20,
                color: AppColors.coralDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.searchingNear(place),
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (radiusM != null)
                      Text(l10n.withinKm(radiusKm(radiusM!)), style: AppText.secondary.copyWith(color: AppColors.brown)),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: l10n.changeAreaLabel,
                excludeSemantics: true,
                child: TextButton(
                  key: changeKey,
                  onPressed: onChange,
                  style: TextButton.styleFrom(minimumSize: const Size(kHealthTapTarget, kHealthTapTarget)),
                  child: Text(l10n.changeArea),
                ),
              ),
            ],
          ),
          if (area.isApproximate)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4, end: 8, bottom: 4),
              child: Text(
                l10n.approximateLocation(((area.accuracyM ?? 0) / 1000).ceil()),
                style: AppText.secondary.copyWith(color: AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }
}
