import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../platform/session.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../presentation/health_widgets.dart';
import '../../../services/pet_records/data/file_services.dart';
import '../../../services/pet_records/state/health_issues.dart';
import '../../../services/pet_records/state/health_providers.dart';
import 'health_pdf.dart';
import 'issue_report.dart';

/// Builds the PDF of one followed problem, in the language on screen, and
/// hands it to the phone's share sheet. A photo that cannot be loaded is
/// left out of the PDF rather than stopping it. Nothing is sent by the app.
Future<void> shareIssuePdf(
  BuildContext context,
  Pet pet,
  IssueDigest digest, {
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
    final repository = container.read(healthIssuesRepositoryProvider);
    final photos = <String, Uint8List>{};
    for (final photo in digest.photos) {
      try {
        photos[photo.id] = await repository.entryPhotoBytes(photo);
      } catch (_) {
        // Left out of the PDF.
      }
    }
    if (!context.mounted || !current()) return;
    final report = buildIssueReport(
      format: HealthFormat.of(context),
      pet: pet,
      digest: digest,
      now: container.read(healthClockProvider)(),
      photos: photos,
      ownerName: container.read(authControllerProvider).value?.displayName ?? '',
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
