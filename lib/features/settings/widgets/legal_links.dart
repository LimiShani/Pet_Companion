import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/link_opener.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Settings' "About PetLoop" card: the Terms of Use and the Privacy
/// Policy, opened in the browser in the app's language.
class LegalLinks extends ConsumerWidget {
  const LegalLinks({super.key});

  static const termsKey = Key('settings-legal-terms');
  static const privacyKey = Key('settings-legal-privacy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;

    Future<void> open(Uri url) async {
      final opened = await ref.read(linkOpenerProvider).open(url);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.legalOpenFailed)));
      }
    }

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _LinkRow(
            key: termsKey,
            icon: Icons.gavel_rounded,
            label: l10n.legalTerms,
            onTap: () => open(AppConfig.termsUrl(language)),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.cream),
          _LinkRow(
            key: privacyKey,
            icon: Icons.privacy_tip_outlined,
            label: l10n.legalPrivacy,
            onTap: () => open(AppConfig.privacyUrl(language)),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.coralDark, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.brown,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
