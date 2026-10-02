import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../health/state/health_keeper.dart';
import '../../health/state/health_providers.dart';
import '../../health/widgets/health_widgets.dart';
import '../state/care_logic.dart';
import '../state/care_providers.dart';

/// Keeps a pet's care data (and the health data it is made of) active
/// while [child] is mounted, for the reason given on `HealthKeeper`: Home
/// stays below the feeding and activity pages, and its data must follow
/// what is logged there without rebuilding in the middle of a frame.
class CareKeeper extends StatefulWidget {
  const CareKeeper({super.key, required this.petId, required this.child});

  final String petId;
  final Widget child;

  @override
  State<CareKeeper> createState() => _CareKeeperState();
}

class _CareKeeperState extends State<CareKeeper> {
  ProviderContainer? _container;
  final _subscriptions = <ProviderSubscription<Object?>>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context);
    if (!identical(container, _container)) {
      _container = container;
      _listen();
    }
  }

  @override
  void didUpdateWidget(CareKeeper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId) _listen();
  }

  void _listen() {
    final old = [..._subscriptions];
    _subscriptions.clear();
    final container = _container!;
    final id = widget.petId;
    void keep<T>(ProviderListenable<T> provider) =>
        _subscriptions.add(container.listen<T>(provider, (_, _) {}, onError: (_, _) {}));
    keep(carePlanProvider(id));
    keep(healthRecordsProvider(id));
    keep(careSettingsProvider(id));
    keep(feedingDayProvider(id));
    keep(activityDayProvider(id));
    keep(upcomingHealthProvider(id));
    for (final sub in old) {
      sub.close();
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HealthKeeper(petId: widget.petId, keep: HealthKeep.emergency, child: widget.child);
}

/// A full page over the app for one pet's care: coral header, scrolling
/// body, the pet's data kept loaded while it is open.
class CarePage extends StatelessWidget {
  const CarePage({super.key, required this.petId, required this.title, required this.child});

  final String petId;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => CareKeeper(
    petId: petId,
    child: HealthPage(title: title, petId: petId, child: child),
  );
}

/// A white rounded block of a care page.
class CareBox extends StatelessWidget {
  const CareBox({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The small heading above a group of a care page.
class CareSectionLabel extends StatelessWidget {
  const CareSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, top: 8, bottom: 6),
      child: Text(text, style: AppText.label.copyWith(color: AppColors.brown)),
    ),
  );
}

/// A rounded progress bar on a white or coloured background.
class CareProgress extends StatelessWidget {
  const CareProgress({super.key, required this.value, this.color = AppColors.coral, this.track});

  final double value;
  final Color color;
  final Color? track;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value,
    minHeight: 8,
    color: color,
    backgroundColor: track ?? AppColors.cream,
    borderRadius: BorderRadius.circular(4),
  );
}

/// Seven bars, one per day, today last and in coral. [goal] draws a
/// faint line across the chart.
///
/// Time runs left to right in both languages, like the weight chart: a
/// chart's time axis is not text and is not mirrored.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.week, required this.color, this.goal});

  static const chartKey = Key('care-week-bars');

  final List<DayTotal> week;
  final Color color;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    final format = AppFormat.of(context);
    final top = [for (final d in week) d.value, goal ?? 0].fold<int>(1, (a, b) => a > b ? a : b);
    const height = 72.0;
    return Semantics(
      label: [for (final d in week) '${format.weekdayShort(d.day.weekday)} ${format.integer(d.value)}'].join(', '),
      child: ExcludeSemantics(
        child: Directionality(textDirection: TextDirection.ltr, child: _bars(format, top, height)),
      ),
    );
  }

  Widget _bars(AppFormat format, int top, double height) {
    return Column(
      key: chartKey,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < week.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height: week[i].value == 0 ? 3 : height * week[i].value / top,
                          decoration: BoxDecoration(
                            color: i == week.length - 1 ? AppColors.coral : color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (goal != null && goal! > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: height * goal! / top - 1,
                  child: Container(height: 2, color: AppColors.brown.withValues(alpha: 0.35)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final d in week)
              Expanded(
                child: Text(
                  format.weekdayNarrow(d.day.weekday),
                  textAlign: TextAlign.center,
                  style: AppText.secondary.copyWith(fontSize: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One meal or walk of the day: a tick when done, its time and title, and
/// at the end either what was logged or the button that logs it.
class CareEntryTile extends StatelessWidget {
  const CareEntryTile({
    super.key,
    required this.entry,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
    required this.onRemove,
  });

  final CareEntry entry;

  /// What was logged: "140 g · 504 cal", "35 min", "Not eaten".
  final String? detail;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final format = AppFormat.of(context);
    final answered = entry.isAnswered;
    return CareBox(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
      onTap: answered ? onRemove : onAction,
      child: Row(
        children: [
          Icon(
            entry.isDone
                ? Icons.check_circle_rounded
                : entry.isSkipped
                ? Icons.remove_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: entry.isDone ? AppColors.sage : AppColors.brown.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: isolate(format.time(entry.time)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(text: entry.title),
                ],
              ),
              style: AppText.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (answered)
            Text(detail ?? '', style: AppText.secondary)
          else
            CarePillButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}

/// The small outlined pill that logs something ("Fed", "Walk", "Start").
class CarePillButton extends StatelessWidget {
  const CarePillButton({super.key, required this.label, required this.onPressed, this.filled = false});

  final String label;
  final VoidCallback? onPressed;

  /// White fill, for a pill on a coloured card.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.coralDark,
        backgroundColor: filled ? AppColors.white : null,
        side: const BorderSide(color: AppColors.coralDark, width: 1.5),
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: AppText.button(14),
      ),
      child: Text(label),
    );
  }
}

/// A "+" line that adds something not planned.
class CareAddLine extends StatelessWidget {
  const CareAddLine({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CareBox(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_rounded, size: 20, color: AppColors.coralDark),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AppText.body.copyWith(color: AppColors.coralDark, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

/// A settings line: a title, a summary under it, and a chevron.
class CareLinkRow extends StatelessWidget {
  const CareLinkRow({super.key, required this.title, required this.summary, required this.onTap});

  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CareBox(
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.cardTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Text(summary, style: AppText.secondary),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          color: AppColors.brown,
        ),
      ],
    ),
  );
}

/// The day's loading / failure states of a care page.
class CareAsync<T> extends ConsumerWidget {
  const CareAsync({super.key, required this.value, required this.petId, required this.builder});

  final AsyncValue<T> value;
  final String petId;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (value.hasValue && !value.hasError) return builder(value.requireValue);
    if (value.hasError) {
      return HealthLoadError(
        title: context.careL10n.loadFailed,
        error: value.error!,
        onRetry: () {
          ref.invalidate(carePlanProvider(petId));
          ref.invalidate(careSettingsProvider(petId));
          ref.invalidate(healthRecordsProvider(petId));
        },
      );
    }
    return const HealthLoading();
  }
}
