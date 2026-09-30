import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'attachments.dart';

/// Every photo and PDF attached to a pet's records, newest record first,
/// each under the record it belongs to. Reached from the emergency kit,
/// where the papers are needed without hunting through the History.
class PetDocumentsScreen extends ConsumerWidget {
  const PetDocumentsScreen({super.key, required this.pet});

  final Pet pet;

  static Future<void> open(BuildContext context, Pet pet) =>
      pushHealthPage<void>(context, PetDocumentsScreen(pet: pet));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(petHealthDataProvider(pet.id));
    final value = data.value;
    final l10n = context.healthL10n;

    Widget body;
    if (value == null) {
      body = data.hasError
          ? HealthLoadError(
              title: l10n.loadFailedDocuments,
              error: data.error!,
              onRetry: () => refreshHealth(ref, pet.id),
            )
          : const HealthLoading();
    } else {
      final records = [
        for (final record in value.records)
          if (value.documentsOf(record.id).isNotEmpty) record,
      ]..sort((a, b) => b.when.compareTo(a.when));
      body = records.isEmpty
          ? EmptyState(icon: Icons.description_rounded, title: l10n.noDocumentsYet, message: l10n.noDocumentsNote)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final record in records) ...[
                  _RecordHeading(record: record),
                  for (final document in value.documentsOf(record.id))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: DocumentRow(document: document),
                    ),
                ],
                const SizedBox(height: 4),
                FinePrint(l10n.documentsFinePrint),
              ],
            );
    }

    return HealthPage(petId: pet.id, title: l10n.petsDocuments(pet.name), child: body);
  }
}

class _RecordHeading extends StatelessWidget {
  const _RecordHeading({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 10, bottom: 6, start: 2),
      child: Text(
        HealthFormat.of(context).dots([record.title, HealthFormat.of(context).date(record.when)]),
        style: AppText.label.copyWith(color: AppColors.brown),
      ),
    );
  }
}
