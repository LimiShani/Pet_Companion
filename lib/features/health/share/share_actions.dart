import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../data/file_services.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../health_strings.dart';
import '../state/health_providers.dart';
import '../state/schedule_logic.dart';
import '../widgets/health_widgets.dart';
import 'health_pdf.dart';
import 'health_report.dart';

/// Reads a provider's value once, keeping it alive while it loads.
Future<T> _once<T>(ProviderContainer container, ProviderListenable<Future<T>> provider) async {
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
Future<void> shareHealthPdf(BuildContext context, Pet pet, {List<HealthRecord>? records}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final summary = await _once(container, healthSummaryProvider(pet.id).future);
    final listed =
        records ??
        historyRecords(await _once(container, healthRecordsProvider(pet.id).future)).take(summaryRecordLimit).toList();
    if (!context.mounted) return;
    final report = buildHealthReport(
      format: HealthFormat.of(context),
      summary: summary,
      records: listed,
      now: container.read(healthClockProvider)(),
      single: records != null,
    );
    final bytes = await container.read(healthPdfBuilderProvider).build(report);
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
    if (!shared && context.mounted) showHealthSnack(context, context.healthL10n.couldNotOpenShareSheet);
  } catch (error) {
    if (context.mounted) showHealthSnack(context, healthErrorOf(context, error));
  }
}

/// Shares the pet's health summary as a PDF.
Future<void> shareHealthSummary(BuildContext context, Pet pet) => shareHealthPdf(context, pet);

/// Shares one record, with the pet's essentials above it, as a PDF.
Future<void> shareRecord(BuildContext context, Pet pet, HealthRecord record) =>
    shareHealthPdf(context, pet, records: [record]);
