import 'package:flutter/material.dart';

import '../../../services/community/data/community_models.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_icon.dart';
import 'post_photo_view.dart';

/// Opens [photo] full screen, on black, with pinch to zoom.
Future<void> openPhotoViewer(BuildContext context, PostPhoto photo) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(photo: photo),
      ),
    );

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.photo});

  final PostPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: PostPhotoView(
                    photo: photo,
                    aspectRatio: null,
                    fit: BoxFit.contain,
                    rounded: false,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 8,
              start: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: AppColors.white,
                ),
                icon: const AppIcon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
