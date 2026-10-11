import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/findvet/data/local_ranking.dart';
import 'package:pet_companion/features/findvet/data/supabase_vet_finder_repository.dart' show directoryRecord;
import 'package:pet_companion/features/findvet/findvet.dart';

// The rules of docs/find_a_vet.md, without widgets: evidence levels, the
// expiry of live intake reports, stale directory facts, the offline
// ranking, and the region modules.

final now = DateTime.utc(2026, 10, 3, 12);
const rehovot = GeoPoint(31.8928, 34.8113);

VetResult curated(
  String key, {
  required double northKm,
  EmergencyClaimState emergency = EmergencyClaimState.advertised,
  IntakeReport intake = IntakeReport.unknown,
  DateTime? checked,
}) => VetResult(
  key: key,
  facilityId: key,
  name: key,
  location: GeoPoint(rehovot.lat + northKm / 111.0, rehovot.lng),
  fromCurated: true,
  emergency: EmergencyClaim(state: emergency, sourceUrl: 'https://vet.example/$key', checkedAt: checked ?? now),
  intake: intake,
  lastCheckedAt: checked ?? now,
);

void main() {
  group('evidence levels', () {
    test('a map listing is only "listed nearby", whatever its name says', () {
      final listing = VetResult.fromJson({
        'key': 'g:1',
        'name': 'Emergency Animal Hospital 24/7',
        'location': {'lat': 31.9, 'lng': 34.8},
        'fromProvider': true,
        'fromCurated': false,
        // Even a server bug that sent a claim with a listing is ignored:
        // without our directory behind it, it is not evidence.
        'emergency': {'state': 'advertised', 'sourceUrl': 'https://x.example'},
        'open': {'state': 'open', 'basis': 'provider_hours'},
      });
      expect(listing.emergencyState, EmergencyClaimState.notListed);
      expect(listing.evidenceAt(now), {EvidenceLevel.listedNearby, EvidenceLevel.publishedOpen});
    });

    test('an emergency claim needs our directory and a source', () {
      final noSource = VetResult(
        key: 'a',
        name: 'A',
        location: rehovot,
        fromCurated: true,
        emergency: const EmergencyClaim(state: EmergencyClaimState.advertised),
      );
      expect(noSource.emergencyState, EmergencyClaimState.notListed);
      expect(curated('b', northKm: 1).evidenceAt(now), contains(EvidenceLevel.emergencyAdvertised));
    });

    test('a claim whose evidence disappeared is unverified, not advertised', () {
      final r = curated('c', northKm: 1, emergency: EmergencyClaimState.unverified);
      expect(r.emergencyState, EmergencyClaimState.unverified);
      expect(r.evidenceAt(now), isNot(contains(EvidenceLevel.emergencyAdvertised)));
    });

    test('hours that are open give "published open" and never "accepting now"', () {
      final r = curated('d', northKm: 1).copyOpen(OpenState.open);
      expect(r.evidenceAt(now), contains(EvidenceLevel.publishedOpen));
      expect(r.evidenceAt(now), isNot(contains(EvidenceLevel.acceptingNow)));
    });

    test('missing hours are unknown', () {
      final r = VetResult.fromJson({'key': 'e', 'name': 'E', 'location': {'lat': 31.9, 'lng': 34.8}});
      expect(r.opening.state, OpenState.unknown);
    });
  });

  group('live intake reports', () {
    final report = IntakeReport(
      state: IntakeState.accepting,
      species: const ['dog'],
      updatedAt: now.subtract(const Duration(minutes: 30)),
      expiresAt: now.add(const Duration(hours: 1)),
    );

    test('count only until they expire', () {
      expect(report.effectiveAt(now), IntakeState.accepting);
      expect(report.effectiveAt(now.add(const Duration(minutes: 59))), IntakeState.accepting);
      expect(report.effectiveAt(report.expiresAt!), IntakeState.unknown, reason: 'expired at the instant itself');
      expect(report.effectiveAt(now.add(const Duration(hours: 3))), IntakeState.unknown);
    });

    test('a report without an expiry or a time says nothing', () {
      expect(const IntakeReport(state: IntakeState.accepting).effectiveAt(now), IntakeState.unknown);
      expect(
        IntakeReport(state: IntakeState.accepting, expiresAt: now.add(const Duration(hours: 1))).effectiveAt(now),
        IntakeState.unknown,
      );
    });

    test('"accepting now" comes and goes with the report', () {
      final r = curated('f', northKm: 1, intake: report);
      expect(r.evidenceAt(now), contains(EvidenceLevel.acceptingNow));
      expect(r.evidenceAt(now.add(const Duration(hours: 2))), isNot(contains(EvidenceLevel.acceptingNow)));
    });

    test('diverting is not accepting', () {
      final r = curated(
        'g',
        northKm: 1,
        intake: IntakeReport(
          state: IntakeState.diverting,
          updatedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      expect(r.evidenceAt(now), isNot(contains(EvidenceLevel.acceptingNow)));
    });
  });

  group('stale directory facts', () {
    test('are stale after 30 days without a check, or when never checked', () {
      expect(curated('h', northKm: 1, checked: now.subtract(const Duration(days: 29))).isStaleAt(now), isFalse);
      expect(curated('i', northKm: 1, checked: now.subtract(const Duration(days: 31))).isStaleAt(now), isTrue);
      final never = VetResult(key: 'j', name: 'J', location: rehovot, fromCurated: true);
      expect(never.isStaleAt(now), isTrue);
    });

    test('a map listing is never "stale": it is live', () {
      const listing = VetResult(key: 'k', name: 'K', location: rehovot, fromProvider: true);
      expect(listing.isStaleAt(now), isFalse);
    });
  });

  group('ranking our directory without the server', () {
    test('emergency: fresh accepting first, then advertised, diverting, unverified; nearest first', () {
      final accepting = IntakeReport(
        state: IntakeState.accepting,
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final diverting = IntakeReport(
        state: IntakeState.diverting,
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final result = rankDirectoryLocally(
        region: israelRegion,
        mode: VetSearchMode.emergency,
        center: rehovot,
        directory: [
          curated('unverified-near', northKm: 0.5, emergency: EmergencyClaimState.unverified),
          curated('advertised-far', northKm: 8),
          curated('advertised-near', northKm: 2),
          curated('accepting-far', northKm: 9, intake: accepting),
          curated('diverting-near', northKm: 1, intake: diverting),
          const VetResult(key: 'no-claim', name: 'x', location: rehovot, fromCurated: true),
        ],
        now: now,
        providerStatus: ProviderStatus.unreached,
      );
      expect(result.results.map((r) => r.key), [
        'accepting-far',
        'advertised-near',
        'advertised-far',
        'diverting-near',
        'unverified-near',
      ]);
      expect(result.notices, contains('provider_unavailable'));
      expect(result.expanded, isFalse);
    });

    test('an expired accepting report ranks like any advertised facility', () {
      final expired = IntakeReport(
        state: IntakeState.accepting,
        updatedAt: now.subtract(const Duration(hours: 5)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      final result = rankDirectoryLocally(
        region: israelRegion,
        mode: VetSearchMode.emergency,
        center: rehovot,
        directory: [curated('expired-far', northKm: 6, intake: expired), curated('near', northKm: 1)],
        now: now,
        providerStatus: ProviderStatus.error,
      );
      expect(result.results.map((r) => r.key), ['near', 'expired-far']);
    });

    test('emergency widens until two advertised facilities are inside', () {
      final result = rankDirectoryLocally(
        region: israelRegion,
        mode: VetSearchMode.emergency,
        center: rehovot,
        directory: [curated('a', northKm: 3), curated('b', northKm: 40)],
        now: now,
        providerStatus: ProviderStatus.error,
      );
      expect(result.radiusM, 50000);
      expect(result.expanded, isTrue);
      expect(result.notices, contains('radius_expanded'));
      expect(result.results, hasLength(2), reason: 'a second option is offered when one exists');
    });

    test('nothing anywhere: the widest radius and "no results"', () {
      final result = rankDirectoryLocally(
        region: israelRegion,
        mode: VetSearchMode.emergency,
        center: rehovot,
        directory: const [],
        now: now,
        providerStatus: ProviderStatus.error,
      );
      expect(result.results, isEmpty);
      expect(result.radiusM, israelRegion.emergencyLadderM.last);
      expect(result.notices, containsAll(['no_results', 'provider_unavailable']));
    });

    test('long term keeps every record and widens until three', () {
      final result = rankDirectoryLocally(
        region: israelRegion,
        mode: VetSearchMode.longTerm,
        center: rehovot,
        directory: [
          curated('a', northKm: 1, emergency: EmergencyClaimState.notListed),
          curated('b', northKm: 4),
          curated('c', northKm: 7),
        ],
        now: now,
        providerStatus: ProviderStatus.error,
      );
      expect(result.radiusM, 10000);
      expect(result.results.map((r) => r.key), ['a', 'b', 'c']);
    });
  });

  group('directory rows', () {
    test('become directory results with the claim, facts and Hebrew name', () {
      final r = directoryRecord({
        'id': 'f1',
        'name': 'Teaching Hospital',
        'name_he': 'בית חולים',
        'address': 'Street 1',
        'city': 'Town',
        'lat': 31.99,
        'lng': 34.82,
        'phone': '+97230000000',
        'emergency': {'state': 'advertised', 'schedule': '24/7', 'sourceUrl': 'https://h.example/e', 'checkedAt': '2026-10-01T00:00:00Z'},
        'facts': [
          {'key': 'species', 'value': ['dog', 'cat'], 'sourceUrl': 'https://h.example/e', 'checkedAt': '2026-10-01T00:00:00Z'},
        ],
        'last_checked_at': '2026-10-01T00:00:00Z',
        'review_status': 'approved',
      }, language: 'he');
      expect(r.name, 'בית חולים');
      expect(r.address, 'Street 1, Town');
      expect(r.fromCurated, isTrue);
      expect(r.fromProvider, isFalse);
      expect(r.emergencyState, EmergencyClaimState.advertised);
      expect(r.fact('species')!.values, ['dog', 'cat']);
      expect(r.intake.effectiveAt(now), IntakeState.unknown, reason: 'no live report: never "accepting"');
    });
  });

  group('regions', () {
    test('Israel holds Israeli places and nothing far away', () {
      expect(vetRegionAt(rehovot)?.code, 'IL');
      expect(vetRegionAt(const GeoPoint(29.56, 34.95))?.code, 'IL', reason: 'Eilat');
      expect(vetRegionAt(const GeoPoint(51.5, -0.12)), isNull, reason: 'London');
      expect(vetRegionByCode('il'), same(israelRegion));
    });

    test('city search matches Hebrew, English and other spellings, best first', () {
      expect(israelRegion.findLocalities('רחובות').single.nameIn('en'), 'Rehovot');
      expect(israelRegion.findLocalities('beer sheva').single.nameIn('he'), 'באר שבע');
      expect(israelRegion.findLocalities('tel-aviv').first.nameIn('en'), 'Tel Aviv-Yafo');
      expect(israelRegion.findLocalities('r'), isEmpty, reason: 'one letter is not a search');
      final ramat = israelRegion.findLocalities('ramat').map((l) => l.nameIn('en'));
      expect(ramat, containsAll(['Ramat Gan', 'Ramat HaSharon']));
    });

    test('the Israeli towns of Judea and Samaria are searchable and in the region', () {
      expect(israelRegion.findLocalities('מעלה אדומים').single.code, 'maale-adumim');
      expect(israelRegion.findLocalities('maale adumim').single.code, 'maale-adumim');
      expect(israelRegion.findLocalities('Modiin Illit').single.code, 'modiin-illit');
      expect(israelRegion.findLocalities('ביתר').single.code, 'beitar-illit');
      expect(
        israelRegion.findLocalities('modiin').map((l) => l.code),
        containsAll(['modiin-maccabim-reut', 'modiin-illit']),
      );
      expect(vetRegionAt(const GeoPoint(32.1061, 35.1851))?.code, 'IL', reason: 'Ariel');
      expect(vetRegionAt(const GeoPoint(31.5278, 35.1192))?.code, 'IL', reason: 'Kiryat Arba');
    });

    test('a town of Judea and Samaria is the nearest only within its reach', () {
      // A point in Ma'ale Adumim, 600 m from its centre.
      expect(israelRegion.nearestLocality(const GeoPoint(31.7758, 35.2988))?.code, 'maale-adumim');
      // Pisgat Ze'ev: 7.0 km from Ma'ale Adumim's centre, 7.2 km from Jerusalem's.
      const pisgatZeev = GeoPoint(31.8222, 35.2563);
      expect(
        pisgatZeev.distanceTo(israelRegion.localityByCode('maale-adumim')!.point),
        lessThan(pisgatZeev.distanceTo(israelRegion.localityByCode('jerusalem')!.point)),
      );
      expect(israelRegion.nearestLocality(pisgatZeev)?.code, 'jerusalem');
      expect(israelRegion.nearestLocality(pisgatZeev, maxM: 30000)?.code, 'jerusalem');
      expect(israelRegion.nearestLocality(const GeoPoint(32.1058, 35.1902))?.code, 'ariel');
      expect(israelRegion.localityByCode('ariel')?.reachM, 3500);
      expect(israelRegion.localityByCode('jerusalem')?.reachM, isNull);
    });

    test('a town beyond its reach still wins when nothing else is in range', () {
      const near = Locality(code: 'near', names: {'en': 'Near'}, point: GeoPoint(31.0, 35.0), reachM: 1000);
      const far = Locality(code: 'far', names: {'en': 'Far'}, point: GeoPoint(31.1, 35.0));
      VetRegion region(List<Locality> localities) => VetRegion(
        code: 'ZZ',
        bounds: const GeoBounds(south: 30, west: 34, north: 32, east: 36),
        languages: const ['en'],
        center: const GeoPoint(31, 35),
        localities: localities,
        emergencyLadderM: const [10000],
        longTermLadderM: const [5000],
      );
      const spot = GeoPoint(31.02, 35.0); // 2.2 km from Near, 8.9 km from Far
      expect(region([near, far]).nearestLocality(spot)?.code, 'far');
      expect(region([near]).nearestLocality(spot)?.code, 'near');
      expect(region([near, far]).nearestLocality(const GeoPoint(31.005, 35.0))?.code, 'near');
      expect(region([near, far]).nearestLocality(spot, maxM: 5000)?.code, 'near');
    });

    test('a region speaks its own language when the app language has no data', () {
      expect(israelRegion.searchLanguage('he'), 'he');
      expect(israelRegion.searchLanguage('en'), 'en');
      expect(israelRegion.searchLanguage('fr'), 'he');
    });

    test('distances are great-circle metres', () {
      final d = rehovot.distanceTo(const GeoPoint(31.7683, 35.2137)); // Jerusalem
      expect(d, inInclusiveRange(39000, 42000));
    });
  });
}

extension on VetResult {
  VetResult copyOpen(OpenState state) => VetResult(
    key: key,
    name: name,
    location: location,
    facilityId: facilityId,
    fromCurated: fromCurated,
    fromProvider: fromProvider,
    emergency: emergency,
    intake: intake,
    lastCheckedAt: lastCheckedAt,
    opening: OpeningInfo(state: state, basis: OpenBasis.providerHours),
  );
}
