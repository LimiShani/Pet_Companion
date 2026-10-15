import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/access_admin_screen.dart';
import '../../access/access_provider.dart';
import '../../l10n/l10n.dart';
import '../../platform/feature_ui.dart';
import '../../services/findvet/state/find_vet_providers.dart'
    show vetIsAdminProvider;
import '../../services/outdoors/state/parks_providers.dart'
    show ParkCapabilities;
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import 'usage_screen.dart';
import 'widgets/menu_card.dart';
import 'widgets/menu_entry.dart';

/// Which of the admin tools the signed-in account may use. The You page
/// shows its "Admin tools" row when there is [any]; the page lists them.
class AdminTools {
  const AdminTools({
    required this.featureAccess,
    required this.directoryReview,
    required this.parkSuggestions,
    this.usage = false,
  });

  /// Watches the capabilities behind each tool.
  factory AdminTools.of(WidgetRef ref) {
    final admin = ref.watch(capabilityProvider('access.admin'));
    return AdminTools(
      featureAccess: admin,
      directoryReview:
          ref.watch(capabilityProvider('findvet.admin')) &&
          (ref.watch(vetIsAdminProvider).value ?? false),
      parkSuggestions: ref.watch(capabilityProvider(ParkCapabilities.review)),
      usage: admin,
    );
  }

  /// Feature access: who may use which feature.
  final bool featureAccess;

  /// Directory review: the vet directory's findings and pending facilities.
  final bool directoryReview;

  /// Park suggestions waiting for a reviewer.
  final bool parkSuggestions;

  /// Usage: the daily counts of the actions people repeat (the same
  /// administrators as [featureAccess]).
  final bool usage;

  bool get any => featureAccess || directoryReview || parkSuggestions || usage;
}

/// The Admin tools page, from the You page: the admin entries that apply
/// to this account, one row each.
class AdminToolsScreen extends ConsumerWidget {
  const AdminToolsScreen({super.key});

  static const screenKey = Key('admin-tools-screen');
  static const featureAccessKey = Key('admin-tools-feature-access');
  static const directoryReviewKey = Key('admin-tools-directory-review');
  static const parkSuggestionsKey = Key('admin-tools-park-suggestions');
  static const usageKey = Key('admin-tools-usage');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = AdminTools.of(ref);

    return Scaffold(
      key: screenKey,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: context.l10n.youAdminTools, showBack: true),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                16,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                MenuCard(
                  children: [
                    if (tools.featureAccess)
                      MenuEntry(
                        key: featureAccessKey,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        title: context.accessL10n.title,
                        onTap: () => openAccessAdministration(context),
                      ),
                    if (tools.directoryReview)
                      MenuEntry(
                        key: directoryReviewKey,
                        icon: const Icon(Icons.fact_check_outlined),
                        title: context.findVetL10n.adminTitle,
                        subtitle: context.findVetL10n.adminMenuSubtitle,
                        onTap: () =>
                            openFeature<Object>(context, 'directory-review', ''),
                      ),
                    if (tools.parkSuggestions)
                      MenuEntry(
                        key: parkSuggestionsKey,
                        icon: const Icon(Icons.park_outlined),
                        title: context.outdoorsL10n.reviewEntryEmpty,
                        onTap: () =>
                            openFeature<Object>(context, 'parks-review', ''),
                      ),
                    if (tools.usage)
                      MenuEntry(
                        key: usageKey,
                        icon: const Icon(Icons.insights_outlined),
                        title: context.l10n.adminUsage,
                        subtitle: context.l10n.adminUsageSummary,
                        onTap: () => openUsage(context),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
