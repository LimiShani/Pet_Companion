import '../../platform/feature_module.dart';
import 'today_card.dart';

/// Home's Today list: the first thing under the hero, before the cards.
///
/// It has no capability of its own (a new one would need a server
/// change): it shows for an account that can see any of what it lists,
/// and each source keeps its own capability.
final todayModule = FeatureModule(
  id: 'today',
  home: [
    FeatureContribution(
      id: 'today',
      capability:
          'care.view|health.schedule.view|basket.view|firstdays.view|pets.view',
      order: -10,
      builder: (_, _) => const TodayCard(),
    ),
  ],
);
