import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../presentation/health_widgets.dart';
import '../../../services/pet_records/data/file_services.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/data/issue_models.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../../../services/pet_records/state/health_issues.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../records/attachments.dart';

/// The icon of a followed problem (its Add row, Overview row and page).
const issueIcon = Icons.healing_rounded;

/// "June 3" / "3 ביוני": a day and its month by name, in the app's
/// language; the numeric date before the month names are loaded.
String issueDay(HealthFormat format, DateTime day) {
  try {
    final locale = format.app.localeName;
    if (DateFormat.localeExists(locale)) {
      return DateFormat.MMMMd(locale).format(day);
    }
  } catch (_) {
    // Not loaded yet: the numeric form below.
  }
  return format.date(day);
}

/// "4 entries, 2 photos" (the photos only when there are some).
String issueCounts(HealthFormat format, IssueDigest digest) =>
    format.commas([
      format.l10n.issueEntryCount(digest.entries.length),
      if (digest.photos.isNotEmpty)
        format.l10n.issuePhotoCount(digest.photos.length),
    ]);

/// "Ongoing since June 3 · 4 entries, 2 photos": the Overview row's line.
String issueOverviewLine(HealthFormat format, IssueDigest digest) =>
    format.dots([
      format.l10n.issueOverviewOngoing(
        issueDay(format, digest.issue.startedOn),
      ),
      issueCounts(format, digest),
    ]);

/// "Since June 3 · 7 days" while open; "June 3 to June 10 · 7 days" once
/// resolved. No day count on the day it started.
String issueSpanLine(HealthFormat format, HealthIssue issue, DateTime today) {
  final l10n = format.l10n;
  final start = issueDay(format, issue.startedOn);
  final end = issue.resolvedOn;
  final days = daysBetween(issue.startedOn, end ?? dateOnly(today));
  return format.dots([
    end == null ? l10n.issueSince(start) : l10n.issueSpan(start, issueDay(format, end)),
    if (days > 0) l10n.issueDays(days),
  ]);
}

/// "Mobility · Less than usual" for an entry.
String entryTitle(
  HealthFormat format,
  Observation entry,
  SpeciesSettings settings,
) {
  final l10n = format.l10n;
  final value = entry.value;
  final level = entry.level;
  return format.dots([
    l10n.quickLogCategory(settings.category(entry.category)),
    entry.isWeight && value != null
        ? format.weight(value, grams: settings.weightInGrams)
        : level == null
        ? l10n.noted
        : l10n.level(level),
  ]);
}

/// One entry of a problem: when, what, the notes and its photos.
class IssueEntryCard extends StatelessWidget {
  const IssueEntryCard({
    super.key,
    required this.entry,
    required this.photos,
    required this.settings,
    required this.onTap,
  });

  final Observation entry;
  final List<HealthDocument> photos;
  final SpeciesSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final format = HealthFormat.of(context);
    final note = entry.note.trim();
    return HealthCard(
      key: ValueKey('issue-entry-${entry.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconDisc(settings.category(entry.category).icon, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format.dateTime(entry.observedAt),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
                Text(
                  entryTitle(format, entry, settings),
                  style: AppText.cardTitle,
                ),
                if (note.isNotEmpty)
                  TypedText(
                    note,
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final photo in photos) EntryPhotoThumb(photo: photo),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A photo of an entry, small and rounded; it opens full screen, or shows
/// a cross to remove it when [onRemove] is given.
class EntryPhotoThumb extends ConsumerStatefulWidget {
  const EntryPhotoThumb({
    super.key,
    this.photo,
    this.bytes,
    this.onRemove,
    this.size = 56,
  }) : assert(photo != null || bytes != null);

  /// A stored photo.
  final HealthDocument? photo;

  /// A photo not stored yet.
  final Uint8List? bytes;
  final VoidCallback? onRemove;
  final double size;

  @override
  ConsumerState<EntryPhotoThumb> createState() => _EntryPhotoThumbState();
}

class _EntryPhotoThumbState extends ConsumerState<EntryPhotoThumb> {
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EntryPhotoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo?.id != widget.photo?.id ||
        oldWidget.bytes != widget.bytes) {
      _load();
    }
  }

  void _load() {
    final bytes = widget.bytes;
    final photo = widget.photo;
    _bytes = bytes != null
        ? Future.value(bytes)
        : ref.read(healthIssuesRepositoryProvider).entryPhotoBytes(photo!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    final size = widget.size;
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.peach,
      alignment: Alignment.center,
      child: const AppIcon(Icons.image_rounded, color: AppColors.ink),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) return placeholder;
          return Image.memory(
            data,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => placeholder,
          );
        },
      ),
    );
    final photo = widget.photo;
    final remove = widget.onRemove;
    final tappable = Semantics(
      button: true,
      label: remove == null ? l10n.issueOpenPhoto : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: remove == null && photo != null
            ? () => openDocument(context, photo)
            : null,
        child: image,
      ),
    );
    if (remove == null) return tappable;
    // The cross sits on the corner, with a full tap target around it.
    return SizedBox(
      width: size + 14,
      height: size + 14,
      child: Stack(
        children: [
          Positioned(left: 0, bottom: 0, child: tappable),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: l10n.issueRemovePhoto,
                onPressed: remove,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                icon: const AppIcon(Icons.close_rounded, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PhotoSource { camera, gallery }

/// Asks where a photo comes from (camera or photos) and returns it, or
/// `null` when nothing was chosen. A file an entry cannot take (not a
/// photo, over 5 MB) is explained and not returned.
Future<PickedFile?> pickEntryPhoto(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final source = await showHealthSheet<_PhotoSource>(
    context,
    const _PhotoSourceSheet(),
  );
  if (source == null) return null;
  final picker = container.read(attachmentPickerProvider);
  try {
    final file = await switch (source) {
      _PhotoSource.camera => picker.takePhoto(),
      _PhotoSource.gallery => picker.pickPhoto(),
    };
    if (file == null) return null;
    final problem = entryPhotoFailure(file);
    if (problem != null) {
      if (context.mounted) {
        showHealthSnack(
          context,
          context.healthL10n.failure(problem, context.l10n),
        );
      }
      return null;
    }
    return file;
  } catch (error) {
    if (context.mounted) {
      showHealthSnack(context, healthErrorOf(context, error));
    }
    return null;
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    Widget option(
      _PhotoSource source,
      IconData icon,
      String title,
      String detail,
    ) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: HealthCard(
        key: ValueKey('entry-photo-${source.name}'),
        onTap: () => Navigator.of(context).pop(source),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconDisc(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.cardTitle),
                  Text(
                    detail,
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(l10n.issueAddPhoto),
        const SizedBox(height: 12),
        option(
          _PhotoSource.camera,
          Icons.photo_camera_rounded,
          l10n.takeAPhoto,
          l10n.withTheCamera,
        ),
        option(
          _PhotoSource.gallery,
          Icons.photo_library_rounded,
          l10n.chooseAPhoto,
          l10n.fromYourPhotos,
        ),
      ],
    );
  }
}
