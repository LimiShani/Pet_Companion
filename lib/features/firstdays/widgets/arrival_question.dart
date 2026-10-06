import '../../../services/pet_records/state/health_providers.dart'
    show healthClockProvider;
import '../../../services/firstdays/state/arrival_controller.dart';
export '../../../services/firstdays/state/arrival_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../presentation/pets_widgets.dart';
import '../../../services/firstdays/data/first_days_models.dart';

/// Asks for the arrival day: today, or a day of the last 30 (never in the
/// future). Returns `null` when the owner cancelled.
Future<DateTime?> pickArrivalDay(
  BuildContext context, {
  required DateTime now,
  DateTime? initial,
}) {
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
              children: [
                chip(yesKey, true, l10n.answerYes),
                chip(noKey, false, l10n.answerNo),
              ],
            ),
            if (c.arrived == true) ...[
              const SizedBox(height: 10),
              _DayField(
                label: l10n.arrivalDay,
                text: _date.format(c.day),
                onTap: () async {
                  final picked = await pickArrivalDay(
                    context,
                    now: ref.read(healthClockProvider)(),
                    initial: c.day,
                  );
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
  const _DayField({
    required this.label,
    required this.text,
    required this.onTap,
  });

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
            suffixIcon: const AppIcon(
              Icons.calendar_month_rounded,
              color: AppColors.brown,
            ),
          ),
          child: Text(
            text,
            style: AppText.body.copyWith(fontSize: 16, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
