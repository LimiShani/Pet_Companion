import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../services/meetups/data/meetup_models.dart';
import '../../../services/meetups/state/meetups_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../board/meetup_card.dart';
import '../meetups_state.dart';

/// One ad on its own page: from a push ("a new walk at your park", "your
/// ad has ended"), a member page or a park page. Its author gets their
/// tools here.
class MeetupScreen extends ConsumerWidget {
  const MeetupScreen({super.key, required this.meetupId, this.initial});

  static const screenKey = Key('meetup-screen');

  final String meetupId;
  final Meetup? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: MeetupCapabilities.view,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final l10n = context.meetupsL10n;
        final fetched = ref.watch(meetupProvider(meetupId));
        final ad = fetched.hasValue ? fetched.value : initial;
        return MeetupsKeeper(
          board: false,
          also: [meetupProvider(meetupId), myMeetupsProvider],
          child: Scaffold(
            key: screenKey,
            body: Column(
              children: [
                CoralHeader(title: l10n.adTitle, showBack: true),
                Expanded(
                  child: ad == null
                      ? fetched.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Center(
                                child: EmptyState(
                                  icon: Icons.event_busy_rounded,
                                  title: l10n.adGone,
                                  message: '',
                                ),
                              )
                      : ListView(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.screen,
                            14,
                            AppSpacing.screen,
                            24 + MediaQuery.paddingOf(context).bottom,
                          ),
                          children: [MeetupCard(meetup: ad, ownerTools: true)],
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
