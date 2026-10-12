import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';

/// A page of Settings: a coral header with a back arrow and [title], and
/// [children] one under the other in a column that scrolls.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: title, showBack: true),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                16,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet line of explanation under a card of Settings.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 6, top: 8),
      child: Text(
        text,
        style: AppText.label.copyWith(
          color: AppColors.brown,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
