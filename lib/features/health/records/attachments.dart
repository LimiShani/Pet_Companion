import '../../../widgets/app_icon.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../services/pet_records/data/file_services.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../presentation/health_widgets.dart';

enum _AttachmentSource { camera, gallery, pdf }

/// Asks the owner where the file comes from (camera, photos or a PDF from
/// the phone's files) and returns the chosen file, or `null` when nothing
/// was chosen. A file the documents bucket would refuse (wrong type, over
/// 5 MB) is explained and not returned.
Future<PickedFile?> pickAttachment(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final source = await showHealthSheet<_AttachmentSource>(
    context,
    const _AttachmentSourceSheet(),
  );
  if (source == null) return null;
  final picker = container.read(attachmentPickerProvider);
  try {
    final file = await switch (source) {
      _AttachmentSource.camera => picker.takePhoto(),
      _AttachmentSource.gallery => picker.pickPhoto(),
      _AttachmentSource.pdf => picker.pickPdf(),
    };
    if (file == null) return null;
    final problem = file.failure;
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

class _AttachmentSourceSheet extends StatelessWidget {
  const _AttachmentSourceSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    Widget option(
      _AttachmentSource source,
      IconData icon,
      String title,
      String detail,
    ) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: HealthCard(
        key: ValueKey('attach-${source.name}'),
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
        SheetTitle(l10n.addPhotoOrPdf, subtitle: l10n.attachSheetNote),
        const SizedBox(height: 12),
        option(
          _AttachmentSource.camera,
          Icons.photo_camera_rounded,
          l10n.takeAPhoto,
          l10n.withTheCamera,
        ),
        option(
          _AttachmentSource.gallery,
          Icons.photo_library_rounded,
          l10n.chooseAPhoto,
          l10n.fromYourPhotos,
        ),
        option(
          _AttachmentSource.pdf,
          Icons.picture_as_pdf_rounded,
          l10n.chooseAPdf,
          l10n.fromPhoneFiles,
        ),
      ],
    );
  }
}

/// One attached file: a small preview, its name and size, and optionally
/// a remove button.
class AttachmentRow extends StatelessWidget {
  const AttachmentRow({
    super.key,
    required this.name,
    required this.sizeBytes,
    required this.isPdf,
    this.bytes,
    this.onTap,
    this.onRemove,
  });

  final String name;
  final int sizeBytes;
  final bool isPdf;

  /// The photo's content for the preview; not needed for a PDF.
  final Future<Uint8List>? bytes;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final source = bytes;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    return HealthCard(
      onTap: onTap,
      radius: AppSpacing.fieldRadius,
      padding: const EdgeInsetsDirectional.only(
        start: 10,
        end: 4,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 52,
              height: 52,
              color: AppColors.yellow,
              child: isPdf || source == null
                  ? AppIcon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      color: AppColors.ink,
                    )
                  : _Preview(bytes: source),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A file name reads left to right, whatever the screen.
                Text(
                  name,
                  style: AppText.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: directionOfText(
                    name,
                    fallback: TextDirection.ltr,
                  ),
                ),
                Text(
                  format.dots([
                    isPdf ? l10n.fileKindPdf : l10n.fileKindPhoto,
                    format.fileSize(sizeBytes),
                  ]),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: l10n.removeNamed(name),
              icon: const AppIcon(Icons.close_rounded, size: 20),
              color: AppColors.brown,
              constraints: const BoxConstraints(
                minWidth: kHealthTapTarget,
                minHeight: kHealthTapTarget,
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.bytes});

  final Future<Uint8List> bytes;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const AppIcon(Icons.image_rounded, color: AppColors.ink);
        }
        return Image.memory(
          data,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) =>
              const AppIcon(Icons.broken_image_rounded, color: AppColors.ink),
        );
      },
    );
  }
}

/// A stored document with its preview loaded from the repository.
class DocumentRow extends ConsumerStatefulWidget {
  const DocumentRow({super.key, required this.document, this.onRemove});

  final HealthDocument document;
  final VoidCallback? onRemove;

  @override
  ConsumerState<DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends ConsumerState<DocumentRow> {
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DocumentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) _load();
  }

  void _load() {
    if (!widget.document.isImage) {
      _bytes = null;
      return;
    }
    // A failed preview just shows the placeholder icon.
    _bytes =
        ref
            .read(medicalRecordsRepositoryProvider)
            .documentBytes(widget.document)
          ..ignore();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return AttachmentRow(
      key: ValueKey('document-${doc.id}'),
      name: doc.fileName,
      sizeBytes: doc.sizeBytes,
      isPdf: doc.isPdf,
      bytes: _bytes,
      onTap: () => openDocument(context, doc),
      onRemove: widget.onRemove,
    );
  }
}

/// Shows a stored document: a photo opens full screen in the app, a PDF
/// opens in the phone's own viewer.
///
/// A PDF is opened through its short-lived link when the backend has one;
/// otherwise (the sample data, or a phone that cannot open the link) the
/// file itself is handed to the phone's share sheet, where a viewer can be
/// chosen.
Future<void> openDocument(BuildContext context, HealthDocument document) async {
  if (document.isImage) {
    await pushHealthPage<void>(context, PhotoViewScreen(document: document));
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final repo = container.read(medicalRecordsRepositoryProvider);
  final sharer = container.read(fileSharerProvider);
  try {
    final link = await repo.documentLink(document);
    if (link != null && await sharer.openLink(link)) return;
    final bytes = await repo.documentBytes(document);
    final opened = await sharer.share(
      SharedFile(
        name: document.fileName,
        mimeType: document.mimeType,
        bytes: bytes,
      ),
    );
    if (!opened && context.mounted) {
      showHealthSnack(context, context.healthL10n.couldNotOpenFile);
    }
  } catch (error) {
    if (context.mounted) {
      showHealthSnack(context, healthErrorOf(context, error));
    }
  }
}

/// A photo attachment, full screen, with pinch to zoom.
class PhotoViewScreen extends ConsumerStatefulWidget {
  const PhotoViewScreen({super.key, required this.document});

  final HealthDocument document;

  @override
  ConsumerState<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends ConsumerState<PhotoViewScreen> {
  late Future<Uint8List> _bytes = _load();

  Future<Uint8List> _load() =>
      ref.read(medicalRecordsRepositoryProvider).documentBytes(widget.document);

  Future<void> _share() async {
    try {
      final bytes = await _bytes;
      final doc = widget.document;
      final shared = await ref
          .read(fileSharerProvider)
          .share(
            SharedFile(
              name: doc.fileName,
              mimeType: doc.mimeType,
              bytes: bytes,
            ),
          );
      if (!shared && mounted) {
        showHealthSnack(context, context.healthL10n.couldNotOpenShareSheet);
      }
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CoralHeader(
            title: widget.document.fileName,
            showBack: true,
            actions: [
              CoralHeaderAction(
                icon: Icons.ios_share_rounded,
                tooltip: context.healthL10n.shareThisPhoto,
                onPressed: _share,
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<Uint8List>(
              future: _bytes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return HealthLoadError(
                    title: context.healthL10n.loadFailedPhoto,
                    error: snapshot.error!,
                    onRetry: () => setState(() => _bytes = _load()),
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ColoredBox(
                  color: AppColors.ink,
                  child: SizedBox.expand(
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          data,
                          key: const Key('photo-view'),
                          fit: BoxFit.contain,
                          semanticLabel: widget.document.fileName,
                          errorBuilder: (_, _, _) => const AppIcon(
                            Icons.broken_image_rounded,
                            size: 64,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
