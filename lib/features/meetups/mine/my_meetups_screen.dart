import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../services/meetups/data/meetup_models.dart';
import '../../../services/meetups/state/meetups_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../board/meetup_card.dart';
import '../meetup_actions.dart';
import '../meetups_state.dart';

/// "My ads": the member's open ads, then those that ended (a regular one
/// can be renewed, a one-off posted again), then the closed ones, each
/// with the author's tools.
class MyMeetupsScreen extends ConsumerWidget {
  const MyMeetupsScreen({super.key});

  static const screenKey = Key('my-meetups');
  static const newAdKey = Key('my-meetups-new-ad');

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: MeetupCapabilities.view,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final l10n = context.meetupsL10n;
        final mine = ref.watch(myMeetupsProvider);
        final now = ref.watch(meetupsClockProvider)();
        final canPost = ref.watch(capabilityProvider(MeetupCapabilities.post));
        final ads = mine.value ?? const <Meetup>[];
        final open = [
          for (final ad in ads)
            if (ad.status == MeetupStatus.open && ad.expiresAt.isAfter(now)) ad,
        ];
        final ended = [
          for (final ad in ads)
            if (ad.hasEndedAt(now)) ad,
        ];
        final closed = [
          for (final ad in ads)
            if (ad.status == MeetupStatus.closed) ad,
        ];
        Widget section(String title, List<Meetup> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppText.label.copyWith(color: AppColors.brown),
                ),
              ),
            ),
            for (final ad in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MeetupCard(meetup: ad, ownerTools: true),
              ),
          ],
        );

        return MeetupsKeeper(
          board: false,
          also: [myMeetupsProvider],
          child: Scaffold(
            key: screenKey,
            body: Column(
              children: [
                CoralHeader(title: l10n.myAds, showBack: true),
                Expanded(
                  child: ListView(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.screen,
                      14,
                      AppSpacing.screen,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      if (canPost) ...[
                        FilledButton.icon(
                          key: newAdKey,
                          onPressed: () => openMeetupForm(context),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              kHealthTapTarget,
                            ),
                          ),
                          icon: const AppIcon(Icons.add_rounded),
                          label: Text(l10n.newAd),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.limitsNote,
                          style: AppText.secondary.copyWith(
                            color: AppColors.brown,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (mine.hasError && !mine.hasValue)
                        EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: l10n.loadFailed,
                          message: '',
                          actionLabel: context.l10n.commonTryAgain,
                          onAction: () => ref.invalidate(myMeetupsProvider),
                        )
                      else if (!mine.hasValue)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (ads.isEmpty)
                        EmptyState(
                          icon: Icons.campaign_outlined,
                          title: l10n.myAdsEmptyTitle,
                          message: l10n.myAdsEmptyBody,
                        )
                      else ...[
                        if (open.isNotEmpty) section(l10n.sectionOpen, open),
                        if (ended.isNotEmpty) section(l10n.sectionEnded, ended),
                        if (closed.isNotEmpty)
                          section(l10n.sectionClosed, closed),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
