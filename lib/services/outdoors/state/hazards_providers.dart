import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../platform/session.dart';
import '../data/fake_hazards_repository.dart';
import '../data/hazard_models.dart';
import '../data/hazards_repository.dart';
import '../data/park_area.dart';
import '../data/supabase_hazards_repository.dart';
import 'parks_providers.dart' show outsideAreaProvider;

/// Who may do what with hazard reports (`0035_neighbourhood.sql`).
abstract final class HazardCapabilities {
  static const view = 'community.hazards.view';
  static const post = 'community.hazards.post';
}

/// The clock of the reports ("this week", how old). Tests fix it.
final hazardsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final hazardsRepositoryProvider = Provider<HazardsRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseHazardsRepository(sb.Supabase.instance.client)
      : FakeHazardsRepository(
          now: ref.watch(hazardsClockProvider),
          viewerId: () => ref.read(authControllerProvider).value?.id ?? 'demo',
        ),
);

/// Moves on every change the member makes, so the lists load again.
class HazardsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final hazardsRevisionProvider = NotifierProvider<HazardsRevision, int>(
  HazardsRevision.new,
);

/// The locality codes of Outside's area, or `null` until it is known.
final _hazardAreaCodesProvider = Provider<String?>((ref) {
  final area = ref.watch(outsideAreaProvider.select((s) => s.area));
  if (area == null) return null;
  final codes = areaLocalityCodes(area)..sort();
  return codes.join(',');
});

/// The current reports around Outside's area, newest first (the reader's
/// own hidden ones too); empty until an area is known, or without
/// [HazardCapabilities.view].
final areaHazardsProvider = FutureProvider<List<HazardReport>>((ref) async {
  ref.watch(sessionEpochProvider);
  ref.watch(hazardsRevisionProvider);
  if (!ref.watch(capabilityProvider(HazardCapabilities.view))) return const [];
  final codes = ref.watch(_hazardAreaCodesProvider);
  if (codes == null || codes.isEmpty) return const [];
  return ref.read(hazardsRepositoryProvider).current(codes.split(','));
}, retry: (_, _) => null);

/// What the line above the Partners and Parks lists says: the reports
/// members see now (not hidden), newest first.
final shownHazardsProvider = Provider<List<HazardReport>>((ref) {
  final now = ref.watch(hazardsClockProvider)();
  final all = ref.watch(areaHazardsProvider).value ?? const [];
  return [
    for (final report in all)
      if (report.isCurrentAt(now)) report,
  ];
});

/// What the member does with reports. Each change reloads the lists.
class HazardsController extends Notifier<void> {
  @override
  void build() {}

  HazardsRepository get _repository => ref.read(hazardsRepositoryProvider);

  Future<T> _change<T>(String capability, Future<T> Function() action) async {
    requireCapability(ref, capability);
    final ticket = SessionTicket(ref);
    try {
      return await action();
    } finally {
      if (ticket.current) ref.read(hazardsRevisionProvider.notifier).bump();
    }
  }

  Future<String> report(HazardDraft draft) =>
      _change(HazardCapabilities.post, () => _repository.report(draft));

  Future<bool> vote(String id, {required bool gone}) => _change(
    HazardCapabilities.view,
    () => _repository.vote(id, gone: gone),
  );

  Future<void> delete(String id) =>
      _change(HazardCapabilities.view, () => _repository.delete(id));
}

final hazardsControllerProvider = NotifierProvider<HazardsController, void>(
  HazardsController.new,
);
