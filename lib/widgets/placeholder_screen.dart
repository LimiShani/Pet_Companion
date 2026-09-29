import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Simple screen used for tabs that are not implemented yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.icon, required this.message});

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
                child: Icon(icon, size: 48, color: AppColors.coral),
              ),
              const SizedBox(height: 20),
              Text('$title coming soon', style: AppText.petName, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: AppText.body.copyWith(color: AppColors.brown), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
