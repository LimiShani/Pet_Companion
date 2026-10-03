import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../health/state/health_providers.dart';
import '../../pets/widgets/pets_widgets.dart';
import '../data/first_days_models.dart';
import '../state/first_days_providers.dart';

/// Asks for the arrival day: today, or a day of the last 30 (never in the
/// future). Returns `null` when the owner cancelled.
Future<DateTime?> pickArrivalDay(BuildContext context, {required DateTime now, DateTime? initial}) {
  final today = DateTime(now.year, now.month, now.day);
  return showDatePicker(
    context: context,
    initialDate: initial ?? today,
    firstDate: earliestArrival(now),
    lastDate: today,
    helpText: context.firstDaysL10n.arrivalDay,
  );
}

/// Holds the answer to "Just arrived home?" while the add-a-pet flow is
/// open, and stores it when the step is saved ([apply]).
class ArrivalController extends ChangeNotifier {
  ArrivalController({required DateTime today}) : _day = DateTime(today.year, today.month, today.day);

  /// Starts on today by the app's clock (the sample data's day in the demo).
  factory ArrivalController.today(WidgetRef ref) => ArrivalController(today: ref.read(healthClockProvider)());

  bool? _arrived;
  DateTime _day;

  /// The arrival day stored by the last [apply], or `null` when no path is
  /// stored from this flow.
  DateTime? _stored;

  /// `true` for "Yes", `false` for "No", `null` while not answered.
  bool? get arrived => _arrived;
  set arrived(bool? value) {
    _arrived = value;
    notifyListeners();
  }

  DateTime get day => _day;
  set day(DateTime value) {
    _day = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  /// Starts the first 30 days of the pet with [petId] when the answer is
  /// "Yes" (or moves it to a new day), and takes back the path started by
  /// an earlier [apply] when the answer is no longer "Yes". Throws a
  /// `HealthException` when it is not stored.
  Future<void> apply(WidgetRef ref, String petId) async {
    final wanted = _arrived == true ? _day : null;
    if (wanted == _stored) return;
    // Kept alive for the call: nothing may be showing it yet.
    final keep = ref.listenManual(firstDaysProvider(petId), (_, _) {});
    try {
      final paths = ref.read(firstDaysProvider(petId).notifier);
      if (wanted == null) {
        await paths.forget();
      } else {
        await paths.start(wanted);
      }
      _stored = wanted;
    } finally {
      keep.close();
    }
  }
}

/// "Just arrived home?" with Yes / No, and the arrival day once the answer
/// is Yes. Driven by an [ArrivalController].
class ArrivalQuestion extends ConsumerWidget {
  const ArrivalQuestion({super.key, required this.controller});

  static const yesKey = Key('arrived-yes');
  static const noKey = Key('arrived-no');
  static const dayKey = Key('arrival-day');

  final ArrivalController controller;

  static final _date = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.firstDaysL10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        Widget chip(Key key, bool value, String label) => ChoiceChip(
          key: key,
          label: Text(label),
          selected: c.arrived == value,
          showCheckmark: false,
          onSelected: (chosen) => c.arrived = chosen ? value : null,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PetsLabel(l10n.arrivedQuestion),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [chip(yesKey, true, l10n.answerYes), chip(noKey, false, l10n.answerNo)],
            ),
            if (c.arrived == true) ...[
              const SizedBox(height: 10),
              _DayField(
                label: l10n.arrivalDay,
                text: _date.format(c.day),
                onTap: () async {
                  final picked = await pickArrivalDay(context, now: ref.read(healthClockProvider)(), initial: c.day);
                  if (picked != null) c.day = picked;
                },
              ),
              const SizedBox(height: 6),
              PetsFinePrint(l10n.arrivalNote),
            ],
          ],
        );
      },
    );
  }
}

/// A field that opens the date picker, as the birthday field does.
class _DayField extends StatelessWidget {
  const _DayField({required this.label, required this.text, required this.onTap});

  final String label;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        key: ArrivalQuestion.dayKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const AppIcon(Icons.calendar_month_rounded, color: AppColors.brown),
          ),
          child: Text(text, style: AppText.body.copyWith(fontSize: 16, color: AppColors.ink)),
        ),
      ),
    );
  }
}
