import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import '../../../access/access_provider.dart';
import '../../../platform/session.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../services/pet_records/data/file_services.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../services/pet_records/state/schedule_logic.dart';
import '../../../presentation/health_widgets.dart';
import 'health_pdf.dart';
import 'health_report.dart';

/// Reads a provider's value once, keeping it alive while it loads.
Future<T> _once<T>(
  ProviderContainer container,
  ProviderListenable<Future<T>> provider,
) async {
  final sub = container.listen(provider, (_, _) {});
  try {
    return await sub.read();
  } finally {
    sub.close();
  }
}

/// Builds the PDF of [pet], in the language on screen, and hands it to the
/// phone's share sheet.
///
/// [records]: the records the table lists. Without it, the summary carries
/// the recent history. The owner chooses where it goes; nothing is sent by
/// the app.
Future<void> shareHealthPdf(
  BuildContext context,
  Pet pet, {
  List<HealthRecord>? records,
  String capability = 'health.records.export',
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(capabilityProvider(capability))) return;
  final epoch = container.read(sessionEpochProvider);
  bool current() =>
      context.mounted &&
      container.read(sessionEpochProvider) == epoch &&
      container.read(capabilityProvider(capability));
  try {
    final summary = await _once(
      container,
      healthSummaryProvider(pet.id).future,
    );
    final listed =
        records ??
        historyRecords(
          await _once(container, healthRecordsProvider(pet.id).future),
        ).take(summaryRecordLimit).toList();
    if (!context.mounted || !current()) return;
    final report = buildHealthReport(
      format: HealthFormat.of(context),
      summary: summary,
      records: listed,
      now: container.read(healthClockProvider)(),
      single: records != null,
    );
    final bytes = await container.read(healthPdfBuilderProvider).build(report);
    if (!context.mounted || !current()) return;
    final shared = await container
        .read(fileSharerProvider)
        .share(
          SharedFile(
            name: report.fileName,
            mimeType: 'application/pdf',
            bytes: bytes,
            // A mail subject is plain text: no direction marks.
            subject: stripBidiMarks(report.title),
          ),
        );
    if (!shared && context.mounted) {
      showHealthSnack(context, context.healthL10n.couldNotOpenShareSheet);
    }
  } catch (error) {
    if (context.mounted) {
      showHealthSnack(context, healthErrorOf(context, error));
    }
  }
}

/// Shares the pet's health summary as a PDF.
Future<void> shareHealthSummary(BuildContext context, Pet pet) =>
    shareHealthPdf(context, pet);

/// Shares one record, with the pet's essentials above it, as a PDF.
Future<void> shareRecord(BuildContext context, Pet pet, HealthRecord record) =>
    shareHealthPdf(context, pet, records: [record]);
