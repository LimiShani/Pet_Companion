import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart' show HealthSheetBody, SheetTitle;
import '../../../services/findvet/regions/regions.dart' show Locality;
import '../../../services/outdoors/data/hazard_models.dart';
import '../../../services/outdoors/data/park_area.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/hazards_providers.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../outdoors_words.dart';
import '../parks/park_picker.dart';
import 'hazard_line.dart';

/// "Report a hazard": what (five kinds), where (a saved park, another park,
/// or somewhere else in Outside's city), a short note. [park] chosen
/// already when opened from a park.
Future<void> openReportHazard(BuildContext context, {DogPark? park}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HealthSheetBody(child: ReportHazardSheet(park: park)),
    );

class ReportHazardSheet extends ConsumerStatefulWidget {
  const ReportHazardSheet({super.key, this.park});

  final DogPark? park;

  static const otherParkKey = Key('hazard-other-park');
  static const elsewhereKey = Key('hazard-elsewhere');
  static const noteKey = Key('hazard-note');
  static const reportKey = Key('hazard-report');
  static Key kindKey(HazardKind kind) => Key('hazard-kind-${kind.name}');
  static Key parkKey(String id) => Key('hazard-park-$id');

  @override
  ConsumerState<ReportHazardSheet> createState() => _ReportHazardSheetState();
}

class _ReportHazardSheetState extends ConsumerState<ReportHazardSheet> {
  final _note = TextEditingController();
  HazardKind? _kind;
  late DogPark? _park = widget.park;

  /// A park from the picker that is not among the saved ones.
  late DogPark? _picked = widget.park;

  /// "Somewhere else in" Outside's city.
  var _elsewhere = false;
  var _busy = false;
  var _defaulted = false;
  String? _problem;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Outside's city: the chosen one, or the one "Near me" stands for.
  Locality? _city() => switch (ref.read(outsideAreaProvider).area) {
    CityArea(:final locality) => locality,
    NearMeArea(:final nearest) => nearest,
    null => null,
  };

  Future<void> _pickPark() async {
    final picked = await pickPark(context);
    if (picked == null || !mounted) return;
    setState(() {
      _park = picked.park;
      _picked = picked.park;
      _elsewhere = false;
      _problem = null;
    });
  }

  Future<void> _report() async {
    final l10n = context.outdoorsL10n;
    final city = _city();
    final note = _note.text.trim();
    final problem = _kind == null
        ? l10n.hazardNeedKind
        : _park == null && !(_elsewhere && city != null)
        ? l10n.hazardNeedPlace
        : _kind == HazardKind.other && note.isEmpty
        ? l10n.hazardNeedNote
        : null;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(hazardsControllerProvider.notifier)
          .report(
            HazardDraft(
              kind: _kind!,
              parkId: _elsewhere ? null : _park?.id,
              localityCode: _elsewhere ? city?.code : _park?.localityCode,
              note: note,
            ),
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.hazardReported)));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is HazardException && e.failure == HazardFailure.rateLimited
                ? l10n.hazardRateLimited
                : l10n.hazardFailed,
          ),
        ),
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final saved = ref.watch(savedParksProvider).value ?? const <DogPark>[];
    final first = saved.take(4).toList();
    final extra = first.any((p) => p.id == _picked?.id) ? null : _picked;
    final parks = [...first, ?extra];
    // The first saved park to start with (as the going-now sheet does).
    if (!_defaulted && _park == null && saved.isNotEmpty) {
      _defaulted = true;
      _park = saved.first;
    }
    final city = _city();
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text, style: AppText.label.copyWith(color: AppColors.brown)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        SheetTitle(l10n.addReportHazard),
        label(l10n.hazardWhat),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final kind in HazardKind.values)
              ChoiceChip(
                key: ReportHazardSheet.kindKey(kind),
                label: Text(l10n.hazardKind(kind)),
                selected: _kind == kind,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _kind = kind;
                  _problem = null;
                }),
              ),
          ],
        ),
        label(l10n.hazardWhere),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final park in parks)
              ChoiceChip(
                key: ReportHazardSheet.parkKey(park.id),
                label: Text(
                  l10n.parkTitle(park, language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: !_elsewhere && _park?.id == park.id,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _park = park;
                  _elsewhere = false;
                  _problem = null;
                }),
              ),
            ActionChip(
              key: ReportHazardSheet.otherParkKey,
              avatar: const Icon(Icons.search_rounded, size: 18),
              label: Text(l10n.hazardOtherPark),
              onPressed: _pickPark,
            ),
            if (city != null)
              ChoiceChip(
                key: ReportHazardSheet.elsewhereKey,
                label: Text(
                  l10n.hazardElsewhereIn(city.nameIn(language)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: _elsewhere,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _elsewhere = true;
                  _problem = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: ReportHazardSheet.noteKey,
          controller: _note,
          maxLength: HazardLimits.note,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l10n.hazardNoteHint),
        ),
        Text(
          l10n.hazardFinePrint,
          style: AppText.label.copyWith(color: AppColors.brown),
        ),
        if (_problem case final problem?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              problem,
              style: AppText.secondary.copyWith(color: AppColors.coralDark),
            ),
          ),
        const SizedBox(height: 12),
        PrimaryButton(
          key: ReportHazardSheet.reportKey,
          label: l10n.hazardReportButton,
          loading: _busy,
          onPressed: _report,
        ),
      ],
    );
  }
}
