import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/language_choice.dart';
import 'widgets/week_choice.dart';

/// The Settings page: the app's language and the week layout. Every choice
/// applies at once and is remembered on the phone (see `SettingsStore`).
///
/// Opened from the side menu and from the account sheet with
/// `openSettings`.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const screenKey = Key('settings-screen');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      key: screenKey,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.settingsTitle, showBack: true),
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
                children: [
                  _SectionLabel(l10n.accountLanguage),
                  const LanguageChoice(),
                  _Note(l10n.languageNote),
                  const SizedBox(height: 16),
                  _SectionLabel(l10n.settingsWeek),
                  const WeekChoice(),
                  _Note(l10n.settingsWeekNote),
                  const SizedBox(height: 16),
                  _Note(l10n.settingsSavedNote),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 6, bottom: 6),
        child: Text(text, style: AppText.label.copyWith(color: AppColors.brown)),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 6, top: 8),
      child: Text(text, style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600)),
    );
  }
}
