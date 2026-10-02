import '../../../widgets/app_icon.dart';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/photo_services.dart';
import '../pet_words.dart';

/// Fits a photo into the round profile shape: the photo moves and zooms
/// under a fixed round window, and two small previews show the result at
/// pet-pill and dashboard size.
///
/// Pops with a [CropOutcome]. Built on the pure-Flutter `crop_your_image`
/// widget, so it needs nothing from the Android and iOS projects.
class CropPhotoScreen extends StatefulWidget {
  const CropPhotoScreen({super.key, required this.photo});

  final Uint8List photo;

  @override
  State<CropPhotoScreen> createState() => _CropPhotoScreenState();
}

class _CropPhotoScreenState extends State<CropPhotoScreen> {
  static const _background = Color(0xFF2A2017);

  final _controller = CropController();
  bool _ready = false;
  bool _working = false;
  String? _error;

  /// Where the round window and the photo sit in the editor, to draw the
  /// previews from.
  Rect? _window;
  Rect? _photoRect;

  void _use() {
    if (!_ready || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    _controller.crop();
  }

  Future<void> _cropped(CropResult result) async {
    try {
      if (result is! CropSuccess) throw StateError('crop failed');
      final jpeg = await squarePetPhotoInBackground(result.croppedImage);
      if (mounted) Navigator.of(context).pop(CropOutcome.cropped(jpeg));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e is StateError ? context.petsL10n.cropFailed : petsErrorOf(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final white = AppColors.white.withValues(alpha: 0.8);
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(const CropOutcome.cancelled()),
                    tooltip: context.l10n.commonBack,
                    icon: const AppIcon(Icons.arrow_back_rounded),
                    color: AppColors.white,
                    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      context.petsL10n.cropTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.appTitle.copyWith(fontSize: 20, color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // A photo has no reading direction: the editor works in
              // screen coordinates, the same in every language.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Crop(
                  image: widget.photo,
                  controller: _controller,
                  onCropped: _cropped,
                  withCircleUi: true,
                  interactive: true,
                  fixCropRect: true,
                  baseColor: Colors.black,
                  maskColor: const Color(0xAD1E140C),
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(size: 0.9, aspectRatio: 1),
                  cornerDotBuilder: (_, _) => const SizedBox.shrink(),
                  progressIndicator: const CircularProgressIndicator(color: AppColors.yellow),
                  onStatusChanged: (status) {
                    if (mounted && status == CropStatus.ready && !_ready) setState(() => _ready = true);
                  },
                  onMoved: (window, _) {
                    if (mounted) setState(() => _window = window);
                  },
                  onImageMoved: (photoRect) {
                    if (mounted) setState(() => _photoRect = photoRect);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The hint and a failure share this place, so the editor
                  // above keeps its size (and the framing) when one appears.
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 36),
                    child: Center(
                      child: Text(
                        _error ?? context.petsL10n.cropHint,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.secondary.copyWith(color: _error == null ? white : AppColors.yellow),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Text(context.petsL10n.cropPreview, style: AppText.label.copyWith(color: white)),
                      _CropPreview(photo: widget.photo, window: _window, photoRect: _photoRect, size: 22),
                      _CropPreview(
                        photo: widget.photo,
                        window: _window,
                        photoRect: _photoRect,
                        size: 56,
                        ring: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _working ? null : () => Navigator.of(context).pop(const CropOutcome.another()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            side: BorderSide(color: white, width: 2),
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          child: Text(context.petsL10n.cropChooseAnother, textAlign: TextAlign.center),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _ready && !_working ? _use : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            foregroundColor: AppColors.ink,
                            disabledBackgroundColor: AppColors.yellow.withValues(alpha: 0.5),
                            disabledForegroundColor: AppColors.ink,
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          child: _working
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink),
                                )
                              : Text(context.petsL10n.cropUsePhoto, textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is under the round window, drawn at [size].
class _CropPreview extends StatelessWidget {
  const _CropPreview({
    required this.photo,
    required this.window,
    required this.photoRect,
    required this.size,
    this.ring = false,
  });

  final Uint8List photo;
  final Rect? window;
  final Rect? photoRect;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final window = this.window;
    final photoRect = this.photoRect;
    Widget content = const ColoredBox(color: Color(0xFF4A3A2A));
    if (window != null && photoRect != null && window.width > 0) {
      final scale = size / window.width;
      content = Stack(
        children: [
          Positioned(
            left: (photoRect.left - window.left) * scale,
            top: (photoRect.top - window.top) * scale,
            width: photoRect.width * scale,
            height: photoRect.height * scale,
            child: Image.memory(
              photo,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }
    return Container(
      width: size + (ring ? 6 : 0),
      height: size + (ring ? 6 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring ? Border.all(color: AppColors.coral, width: 3) : null,
      ),
      child: ClipOval(child: SizedBox.square(dimension: size, child: content)),
    );
  }
}
