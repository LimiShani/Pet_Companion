import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/session.dart';
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../services/findvet/data/location_service.dart';
import '../../../services/findvet/regions/regions.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../outdoors_words.dart';
import '../widgets/park_widgets.dart';

/// "Suggest a park", over the whole app. Returns whether one was sent.
Future<bool> openSuggestPark(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final thanks = context.outdoorsL10n.sentThanks;
  final sent = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const SuggestParkScreen(),
    ),
  );
  if (sent == true) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(thanks)));
  }
  return sent == true;
}

class SuggestParkScreen extends ConsumerStatefulWidget {
  const SuggestParkScreen({super.key});

  static const screenKey = Key('suggest-park-screen');
  static const nameKey = Key('suggest-park-name');
  static const hereKey = Key('suggest-park-here');
  static const cityFieldKey = Key('suggest-park-city');
  static const placeKey = Key('suggest-park-place');
  static const sendKey = Key('suggest-park-send');
  static Key cityKey(String code) => Key('suggest-park-city-$code');
  static Key answerKey(ParkDetail detail, ParkAnswer answer) =>
      Key('suggest-park-${detail.name}-${answer.name}');

  @override
  ConsumerState<SuggestParkScreen> createState() => _SuggestParkScreenState();
}

class _SuggestParkScreenState extends ConsumerState<SuggestParkScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _place = TextEditingController();
  final _details = <ParkDetail, ParkAnswer>{};

  GeoPoint? _here;
  Locality? _locality;
  List<Locality> _matches = const [];
  bool _locating = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _useHere() async {
    final l10n = context.outdoorsL10n;
    setState(() {
      _locating = true;
      _error = null;
    });
    final result = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    final point = result.point;
    setState(() {
      _locating = false;
      if (result.outcome == LocationOutcome.found && point != null) {
        if (vetRegionAt(point) == null) {
          _error = l10n.problemOutsideRegion;
        } else {
          _here = point;
          _locality = null;
        }
      } else {
        _error = switch (result.outcome) {
          LocationOutcome.denied => l10n.problemDenied,
          LocationOutcome.deniedForever => l10n.problemDeniedForever,
          LocationOutcome.serviceOff => l10n.problemServiceOff,
          _ => l10n.problemUnavailable,
        };
      }
    });
  }

  Future<void> _send() async {
    final l10n = context.outdoorsL10n;
    final place = _place.text.trim();
    final here = _here;
    final locality = _locality;
    if (here == null && (locality == null || place.isEmpty)) {
      setState(() => _error = l10n.needLocation);
      return;
    }
    final name = _name.text.trim();
    final suggestion = NewParkSuggestion(
      name: name.isEmpty ? null : name,
      point: here ?? locality!.point,
      location: here != null
          ? SuggestedLocation.device
          : SuggestedLocation.locality,
      localityCode:
          locality?.code ?? vetRegionAt(here!)?.nearestLocality(here)?.code,
      placeNote: place.isEmpty ? null : place,
      details: {
        for (final entry in _details.entries)
          if (entry.value != ParkAnswer.unknown) entry.key: entry.value,
      },
    );
    final ticket = SessionTicket.widget(ref);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (!ref.read(capabilityProvider(ParkCapabilities.suggest))) {
        throw const FeatureDenied(ParkCapabilities.suggest);
      }
      await ref.read(parksRepositoryProvider).suggestPark(suggestion);
      if (!mounted || !ticket.current) return;
      ref.invalidate(parkReviewQueueProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is ParkException && e.failure == ParkFailure.rateLimited
            ? l10n.rateLimited
            : l10n.sendFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: ParkCapabilities.suggest,
    builder: (context) => _buildForm(context),
  );

  Widget _buildForm(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    return Scaffold(
      key: SuggestParkScreen.screenKey,
      body: Column(
        children: [
          CoralHeader(title: l10n.suggestTitle, showBack: true),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                14,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  l10n.suggestIntro,
                  style: AppText.body.copyWith(color: AppColors.brown),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: SuggestParkScreen.nameKey,
                  controller: _name,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.parkNameLabel),
                ),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(l10n.whereIsIt, style: AppText.cardTitle),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.imHereWhy,
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
                const SizedBox(height: 8),
                if (_here != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.fieldRadius,
                      ),
                    ),
                    child: Row(
                      children: [
                        const AppIcon(
                          Icons.my_location_rounded,
                          color: AppColors.ink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n.hereSet, style: AppText.body),
                        ),
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    key: SuggestParkScreen.hereKey,
                    onPressed: _locating || _sending ? null : _useHere,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(kHealthTapTarget),
                    ),
                    icon: _locating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const AppIcon(Icons.my_location_rounded),
                    label: Text(_locating ? l10n.locating : l10n.imHere),
                  ),
                if (_here == null) ...[
                  const SizedBox(height: 14),
                  Text(
                    l10n.orTheCity,
                    style: AppText.label.copyWith(color: AppColors.brown),
                  ),
                  const SizedBox(height: 6),
                  if (_locality != null)
                    InputChip(
                      label: Text(_locality!.nameIn(language)),
                      onDeleted: () => setState(() => _locality = null),
                    )
                  else ...[
                    TextField(
                      key: SuggestParkScreen.cityFieldKey,
                      controller: _city,
                      onChanged: (text) => setState(() {
                        _matches = [
                          for (final region in vetRegions)
                            ...region.findLocalities(text, limit: 4),
                        ];
                      }),
                      decoration: InputDecoration(
                        labelText: l10n.cityHint,
                        prefixIcon: const AppIcon(Icons.search_rounded),
                      ),
                    ),
                    for (final locality in _matches)
                      ListTile(
                        key: SuggestParkScreen.cityKey(locality.code),
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
                        onTap: () => setState(() {
                          _locality = locality;
                          _matches = const [];
                          _city.clear();
                          _error = null;
                        }),
                      ),
                  ],
                ],
                const SizedBox(height: 10),
                TextField(
                  key: SuggestParkScreen.placeKey,
                  controller: _place,
                  maxLength: 200,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.placeLabel,
                    hintText: l10n.placeHint,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(l10n.detailsOptional, style: AppText.cardTitle),
                ),
                const SizedBox(height: 8),
                for (final detail in ParkDetail.values) ...[
                  Row(
                    children: [
                      AppIcon(
                        parkDetailIcon(detail),
                        size: 18,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.detail(detail),
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final answer in ParkAnswer.values)
                        ChoiceChip(
                          key: SuggestParkScreen.answerKey(detail, answer),
                          label: Text(l10n.answer(answer)),
                          selected:
                              (_details[detail] ?? ParkAnswer.unknown) ==
                              answer,
                          showCheckmark: false,
                          onSelected: _sending
                              ? null
                              : (_) => setState(() => _details[detail] = answer),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: AppText.body.copyWith(color: AppColors.coralDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  key: SuggestParkScreen.sendKey,
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(kHealthTapTarget),
                  ),
                  child: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(l10n.suggestSend),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
