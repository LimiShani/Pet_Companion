import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/l10n.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import 'widgets/legal_links.dart';

/// The About page, from the You page: the Terms of Use and the Privacy
/// Policy (opened in the browser), the credits of the data the installed
/// modules show, and the app's version.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const screenKey = Key('about-screen');
  static const versionKey = Key('about-version');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      key: screenKey,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.aboutTitle, showBack: true),
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
                  const LegalLinks(),
                  _Note(l10n.legalOpensInBrowser),
                  // Credits of the data the installed modules show
                  // (OpenStreetMap): a licence notice, so not gated.
                  Consumer(
                    builder: (context, ref, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final module in ref.watch(featureModulesProvider))
                          if (module.slots['about-credits'] case final slot?)
                            slot.build(context, const FeatureRequest('')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Version(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Version 1.4.0 (12)", read from the build. Nothing is shown where the
/// platform does not tell (a test, a plain desktop run).
class _Version extends StatefulWidget {
  const _Version();

  @override
  State<_Version> createState() => _VersionState();
}

class _VersionState extends State<_Version> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        final version = info.buildNumber.isEmpty
            ? info.version
            : '${info.version} (${info.buildNumber})';
        return _Note(
          context.l10n.aboutVersion(version),
          key: AboutScreen.versionKey,
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});

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
