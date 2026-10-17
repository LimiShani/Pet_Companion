import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../platform/session.dart';
import '../../../services/community/data/community_providers.dart';
import '../../../services/findvet/regions/regions.dart' show Locality;
import '../../../services/meetups/state/meetups_providers.dart'
    show localityOfProfileCity;
import '../../../services/outdoors/data/park_area.dart';
import '../../../services/outdoors/state/parks_providers.dart'
    show outsideAreaProvider, outsideDefaultRadius;

/// The city of the member's own member page, when the localities list
/// knows it ("Tel Aviv" is Tel Aviv-Yafo); `null` otherwise.
final myCityProvider = FutureProvider<Locality?>((ref) async {
  ref.watch(sessionEpochProvider);
  final user = ref.watch(authControllerProvider.select((a) => a.value?.id));
  if (user == null) return null;
  try {
    final profile = await ref
        .watch(communityMembersRepositoryProvider)
        .fetchMember(user);
    return localityOfProfileCity(profile?.city ?? '');
  } catch (_) {
    return null;
  }
}, retry: (_, _) => null);

/// "Me" for the feed's "Near me": the localities within 10 km of the
/// member's city, else of Outside's area (`outsideAreaProvider`); `null`
/// while neither is known (then the chip does not show).
final nearMeCodesProvider = Provider<Set<String>?>((ref) {
  final city = ref.watch(myCityProvider).value;
  if (city != null) {
    return areaLocalityCodes(
      CityArea(city, radius: outsideDefaultRadius),
    ).toSet();
  }
  final area = ref.watch(outsideAreaProvider.select((s) => s.area));
  if (area == null) return null;
  final codes = areaLocalityCodes(area).toSet();
  return codes.isEmpty ? null : codes;
});
