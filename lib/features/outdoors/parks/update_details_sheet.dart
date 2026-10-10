import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/session.dart';
import '../../../presentation/health_widgets.dart'
    show kHealthTapTarget, showHealthSheet, SheetTitle;
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../outdoors_words.dart';
import '../widgets/park_widgets.dart';

/// "Update details": the member says what they saw. Nothing changes on the
/// park until a reviewer approves it.
Future<void> openUpdateDetails(BuildContext context, DogPark park) async {
  final messenger = ScaffoldMessenger.of(context);
  final thanks = context.outdoorsL10n.sentThanks;
  final sent = await showHealthSheet<bool>(
    context,
    UpdateDetailsSheet(park: park),
  );
  if (sent == true) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(thanks)));
  }
}

class UpdateDetailsSheet extends ConsumerStatefulWidget {
  const UpdateDetailsSheet({super.key, required this.park});

  static const sendKey = Key('park-update-send');
  static const closedKey = Key('park-update-closed');
  static Key answerKey(ParkDetail detail, ParkAnswer answer) =>
      Key('park-update-${detail.name}-${answer.name}');

  final DogPark park;

  @override
  ConsumerState<UpdateDetailsSheet> createState() => _UpdateDetailsSheetState();
}

class _UpdateDetailsSheetState extends ConsumerState<UpdateDetailsSheet> {
  late final Map<ParkDetail, ParkAnswer> _answers = {
    for (final detail in ParkDetail.values)
      detail: widget.park.answer(detail),
  };
  late bool _closed = widget.park.isClosed;
  bool _sending = false;
  String? _error;

  Map<ParkDetail, ParkAnswer> get _changes => {
    for (final entry in _answers.entries)
      if (entry.value != widget.park.answer(entry.key)) entry.key: entry.value,
  };

  bool get _closedChanged => _closed != widget.park.isClosed;

  bool get _changed => _changes.isNotEmpty || _closedChanged;

  Future<void> _send() async {
    final l10n = context.outdoorsL10n;
    if (!_changed) {
      setState(() => _error = l10n.nothingChanged);
      return;
    }
    final ticket = SessionTicket.widget(ref);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (!ref.read(capabilityProvider(ParkCapabilities.suggest))) {
        throw const FeatureDenied(ParkCapabilities.suggest);
      }
      await ref
          .read(parksRepositoryProvider)
          .suggestDetails(
            widget.park.id,
            _changes,
            closed: _closedChanged ? _closed : null,
          );
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
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        SheetTitle(
          l10n.updateTitle,
          subtitle: l10n.parkFullName(widget.park, language),
        ),
        const SizedBox(height: 8),
        Text(l10n.updateIntro, style: AppText.body.copyWith(color: AppColors.brown)),
        const SizedBox(height: 12),
        for (final detail in ParkDetail.values) ...[
          Row(
            children: [
              AppIcon(parkDetailIcon(detail), size: 18, color: AppColors.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.detail(detail),
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
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
                  key: UpdateDetailsSheet.answerKey(detail, answer),
                  label: Text(l10n.answer(answer)),
                  selected: _answers[detail] == answer,
                  showCheckmark: false,
                  onSelected: _sending
                      ? null
                      : (_) => setState(() {
                          _answers[detail] = answer;
                          _error = null;
                        }),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          key: UpdateDetailsSheet.closedKey,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.closedSwitch, style: AppText.body),
          value: _closed,
          onChanged: _sending
              ? null
              : (value) => setState(() {
                  _closed = value;
                  _error = null;
                }),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: AppText.body.copyWith(color: AppColors.coralDark),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: UpdateDetailsSheet.sendKey,
          onPressed: _sending ? null : _send,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(kHealthTapTarget),
          ),
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(l10n.send),
        ),
      ],
    );
  }
}
