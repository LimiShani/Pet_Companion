import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../health/widgets/health_widgets.dart' show kHealthTapTarget;
import '../data/vet_models.dart';
import '../findvet_words.dart';

/// One facility of the results, with what we know about it and how sure
/// we are, then Call and Directions (and Save for long term care).
///
/// The four evidence levels never blur: "listed nearby" (a map listing),
/// "emergency service advertised" (its own website, with the check date),
/// "published hours" (open/closed/unknown) and "accepting now" (only a
/// fresh report from the facility; otherwise "Call to confirm").
class VetResultCard extends StatefulWidget {
  const VetResultCard({
    super.key,
    required this.result,
    required this.mode,
    required this.now,
    required this.onCall,
    required this.onDirections,
    required this.onOpenLink,
    this.onSave,
    this.optionLabel,
  });

  static Key cardKey(String key) => Key('findvet-card-$key');
  static Key callKey(String key) => Key('findvet-call-$key');
  static Key directionsKey(String key) => Key('findvet-directions-$key');
  static Key saveKey(String key) => Key('findvet-save-$key');
  static Key detailsKey(String key) => Key('findvet-details-$key');

  final VetResult result;
  final VetSearchMode mode;
  final DateTime now;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final ValueChanged<String> onOpenLink;

  /// Long term care only: save as a pet's regular vet. `null` hides it
  /// (emergency, or nobody signed in).
  final VoidCallback? onSave;

  /// "Nearest option" / "Second option" above the name.
  final String? optionLabel;

  @override
  State<VetResultCard> createState() => _VetResultCardState();
}

class _VetResultCardState extends State<VetResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final l10n = context.findVetL10n;
    final emergency = widget.mode == VetSearchMode.emergency;
    final hasDetails = (r.opening.weekdayText.isNotEmpty || r.mapsUri != null || r.website != null);

    return Container(
      key: VetResultCard.cardKey(r.key),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
        border: widget.optionLabel != null ? Border.all(color: AppColors.coral, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.optionLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.optionLabel!,
                style: AppText.label.copyWith(color: AppColors.coralDark, fontWeight: FontWeight.w800),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    r.name,
                    textDirection: directionOfText(r.name, fallback: Directionality.of(context)),
                    style: AppText.cardTitle.copyWith(fontSize: 17),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (r.distanceM != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatDistance(context, r.distanceM!),
                  style: AppText.body.copyWith(fontWeight: FontWeight.w800, color: AppColors.brown),
                ),
              ],
            ],
          ),
          if (r.address != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                r.address!,
                textDirection: directionOfText(r.address!, fallback: Directionality.of(context)),
                style: AppText.secondary.copyWith(color: AppColors.brown),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 10),
          if (emergency) ...[
            _IntakeLine(result: r, now: widget.now),
            _EmergencyLine(result: r),
            _OpenLine(result: r),
          ] else ...[
            if (r.fromProvider) _Line(icon: Icons.place_outlined, text: l10n.evidenceListed),
            _OpenLine(result: r),
            _FactLine(result: r, factKey: 'species'),
            _FactLine(result: r, factKey: 'services'),
            if (r.emergencyState == EmergencyClaimState.advertised) _EmergencyLine(result: r),
          ],
          if (r.businessStatus == 'closed_temporarily')
            _Line(icon: Icons.warning_amber_rounded, text: l10n.closedTemporarily, strong: true),
          if (r.isStaleAt(widget.now))
            _Line(
              icon: Icons.history_rounded,
              text: r.lastCheckedAt == null
                  ? l10n.staleNever
                  : l10n.staleNote(AppFormat.of(context).date(r.lastCheckedAt!.toLocal())),
            ),
          if (_expanded && hasDetails) _Details(result: r, onOpenLink: widget.onOpenLink),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (r.hasPhone)
                Semantics(
                  button: true,
                  label: l10n.callName(r.name),
                  excludeSemantics: true,
                  child: FilledButton.icon(
                    key: VetResultCard.callKey(r.key),
                    onPressed: widget.onCall,
                    style: FilledButton.styleFrom(minimumSize: const Size(112, kHealthTapTarget)),
                    icon: const AppIcon(Icons.call_rounded),
                    label: Text(l10n.call),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l10n.noPhone, style: AppText.secondary.copyWith(color: AppColors.brown)),
                ),
              Semantics(
                button: true,
                label: l10n.directionsName(r.name),
                excludeSemantics: true,
                child: OutlinedButton.icon(
                  key: VetResultCard.directionsKey(r.key),
                  onPressed: widget.onDirections,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(112, kHealthTapTarget)),
                  icon: const AppIcon(Icons.directions_rounded),
                  label: Text(l10n.directions),
                ),
              ),
              if (widget.onSave != null)
                Semantics(
                  button: true,
                  label: l10n.saveName(r.name),
                  excludeSemantics: true,
                  child: OutlinedButton.icon(
                    key: VetResultCard.saveKey(r.key),
                    onPressed: widget.onSave,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(96, kHealthTapTarget)),
                    icon: const AppIcon(Icons.bookmark_add_outlined),
                    label: Text(l10n.save),
                  ),
                ),
              if (hasDetails)
                TextButton(
                  key: VetResultCard.detailsKey(r.key),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(minimumSize: const Size(kHealthTapTarget, kHealthTapTarget)),
                  child: Text(_expanded ? l10n.fewerDetails : l10n.details),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line of evidence: an icon and a sentence, with an optional second
/// line in smaller type.
class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.note, this.strong = false, this.color});

  final IconData icon;
  final String text;
  final String? note;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? (strong ? AppColors.coralDark : AppColors.brown);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1, end: 8),
              child: AppIcon(icon, size: 18, color: tint),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: AppText.body.copyWith(
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                      color: strong ? AppColors.coralDark : AppColors.ink,
                    ),
                  ),
                  if (note != null) Text(note!, style: AppText.secondary.copyWith(color: AppColors.brown)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Accepting now" only from a fresh report of the facility itself;
/// otherwise the call-to-confirm line, always.
class _IntakeLine extends StatelessWidget {
  const _IntakeLine({required this.result, required this.now});

  final VetResult result;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    final intake = result.intake;
    final state = intake.effectiveAt(now);
    if (state == IntakeState.unknown) {
      return _Line(icon: Icons.phone_in_talk_rounded, text: l10n.callToConfirm, strong: true);
    }
    final format = AppFormat.of(context);
    final reported = l10n.evidenceReported(
      format.time(intake.updatedAt!.toLocal()),
      format.time(intake.expiresAt!.toLocal()),
    );
    return switch (state) {
      IntakeState.accepting => _Line(
        icon: Icons.check_circle_rounded,
        text: l10n.evidenceAccepting,
        note: reported,
        color: AppColors.ink,
      ),
      IntakeState.limited => _Line(icon: Icons.info_rounded, text: l10n.evidenceLimited, note: reported),
      _ => _Line(icon: Icons.do_not_disturb_on_rounded, text: l10n.evidenceDiverting, note: reported, strong: true),
    };
  }
}

/// The emergency claim, from our directory only.
class _EmergencyLine extends StatelessWidget {
  const _EmergencyLine({required this.result});

  final VetResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    final claim = result.emergency;
    final format = AppFormat.of(context);
    final checked = claim.checkedAt == null ? null : format.date(claim.checkedAt!.toLocal());
    return switch (result.emergencyState) {
      EmergencyClaimState.advertised => _Line(
        icon: Icons.verified_outlined,
        text: claim.schedule == null ? l10n.evidenceAdvertised : l10n.evidenceAdvertisedSchedule(claim.schedule!),
        note: checked == null ? l10n.evidenceSourceNotChecked : l10n.evidenceSourceChecked(checked),
      ),
      EmergencyClaimState.unverified => _Line(
        icon: Icons.help_outline_rounded,
        text: l10n.evidenceUnverified,
        note: checked == null ? l10n.evidenceUnverifiedNoDate : l10n.evidenceUnverifiedNote(checked),
      ),
      EmergencyClaimState.notListed => _Line(
        icon: Icons.place_outlined,
        text: l10n.evidenceListed,
        note: l10n.evidenceListedNote,
      ),
    };
  }
}

/// Published hours: open, closed or not published.
class _OpenLine extends StatelessWidget {
  const _OpenLine({required this.result});

  final VetResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    return switch (result.opening.state) {
      OpenState.open => _Line(icon: Icons.schedule_rounded, text: l10n.evidenceOpenNow),
      OpenState.closed => _Line(icon: Icons.schedule_rounded, text: l10n.evidenceClosedNow),
      OpenState.unknown => _Line(icon: Icons.schedule_rounded, text: l10n.evidenceHoursUnknown),
    };
  }
}

/// Species or services, only when our directory holds them with a source.
class _FactLine extends StatelessWidget {
  const _FactLine({required this.result, required this.factKey});

  final VetResult result;
  final String factKey;

  @override
  Widget build(BuildContext context) {
    final fact = result.fact(factKey);
    if (fact == null) return const SizedBox.shrink();
    final l10n = context.findVetL10n;
    final list = factKey == 'species'
        ? fact.values.map(l10n.speciesName).join(', ')
        : fact.values.join(', ');
    final checked = fact.checkedAt == null ? null : AppFormat.of(context).date(fact.checkedAt!.toLocal());
    return _Line(
      icon: factKey == 'species' ? Icons.pets_rounded : Icons.medical_services_outlined,
      text: factKey == 'species' ? l10n.speciesLine(list) : l10n.servicesLine(list),
      note: checked == null ? l10n.factSourceNoDate : l10n.factSource(checked),
    );
  }
}

/// Long term care's details: the published week, the website and the
/// place on the provider's map.
class _Details extends StatelessWidget {
  const _Details({required this.result, required this.onOpenLink});

  final VetResult result;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    final r = result;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.opening.weekdayText.isNotEmpty) ...[
            Text(l10n.hoursTitle, style: AppText.label.copyWith(color: AppColors.brown)),
            for (final day in r.opening.weekdayText)
              Text(
                day,
                textDirection: directionOfText(day, fallback: Directionality.of(context)),
                style: AppText.secondary.copyWith(color: AppColors.ink),
              ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 4,
            children: [
              if (r.website != null)
                TextButton.icon(
                  onPressed: () => onOpenLink(r.website!),
                  style: TextButton.styleFrom(minimumSize: const Size(kHealthTapTarget, kHealthTapTarget)),
                  icon: const AppIcon(Icons.language_rounded, size: 18),
                  label: Text(l10n.website),
                ),
              if (r.fromProvider && r.mapsUri != null)
                TextButton.icon(
                  onPressed: () => onOpenLink(r.mapsUri!),
                  style: TextButton.styleFrom(minimumSize: const Size(kHealthTapTarget, kHealthTapTarget)),
                  icon: const AppIcon(Icons.map_outlined, size: 18),
                  label: Text(l10n.viewOnMaps),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
