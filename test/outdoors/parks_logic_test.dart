import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/findvet/regions/regions.dart';

import 'outdoors_test_helpers.dart';

void main() {
  setUpOutdoorsTests();

  group('localities', () {
    test('every locality has a unique lowercase code and both names', () {
      final codes = israelLocalities.map((l) => l.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
      expect(israelLocalities.length, greaterThan(150));
      for (final l in israelLocalities) {
        expect(l.code, matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')));
        expect(l.names['he'], isNotEmpty, reason: l.code);
        expect(l.names['en'], isNotEmpty, reason: l.code);
      }
    });

    test('lookups by code, by distance and within a radius', () {
      expect(israelRegion.localityByCode('raanana')?.nameIn('he'), 'רעננה');
      expect(israelRegion.localityByCode('nowhere'), isNull);
      expect(israelRegion.nearestLocality(raananaSpot)?.code, 'raanana');
      expect(
        israelRegion.nearestLocality(const GeoPoint(31.8222, 35.2563))?.code,
        'jerusalem',
        reason: "Pisgat Ze'ev is beyond the reach of Ma'ale Adumim",
      );
      expect(
        israelRegion.nearestLocality(const GeoPoint(32.5, 33.5)),
        isNull,
        reason: 'the sea is near nothing',
      );
      final around = israelRegion
          .localitiesWithin(raananaSpot, 10000)
          .map((l) => l.code);
      expect(around.first, 'raanana');
      expect(around, containsAll(['kfar-saba', 'herzliya', 'hod-hasharon']));
      expect(around, isNot(contains('jerusalem')));
    });

    test('the new towns are found by name, in both languages', () {
      expect(
        israelRegion.findLocalities('כפר יונה').single.nameIn('en'),
        'Kfar Yona',
      );
      expect(
        israelRegion.findLocalities('even yeh').single.nameIn('he'),
        'אבן יהודה',
      );
    });
  });

  group('areas', () {
    test('the coarse box snaps outwards to the grid and holds the circle', () {
      final box = coarseBox(raananaSpot, 10000);
      for (final edge in [box.south, box.west, box.north, box.east]) {
        final steps = edge / coarseGridDegrees;
        expect((steps - steps.round()).abs(), lessThan(1e-9), reason: '$edge');
      }
      final exact = boxAround(raananaSpot, 10000);
      expect(box.south, lessThanOrEqualTo(exact.south));
      expect(box.north, greaterThanOrEqualTo(exact.north));
      expect(box.west, lessThanOrEqualTo(exact.west));
      expect(box.east, greaterThanOrEqualTo(exact.east));
    });

    test('nearby phones send the same box: it does not reveal the spot', () {
      expect(
        ParkQuery.of(NearMeArea(point: raananaSpot)),
        ParkQuery.of(NearMeArea(point: const GeoPoint(32.1862, 34.8731))),
      );
    });

    test('"City only" asks for the locality; a radius asks for a box', () {
      final raanana = israelRegion.localityByCode('raanana')!;
      final cityOnly = ParkQuery.of(CityArea(raanana));
      expect(cityOnly.localityCode, 'raanana');
      expect(cityOnly.box, isNull);
      final wide = ParkQuery.of(CityArea(raanana, radius: ParkRadius.km25));
      expect(wide.localityCode, isNull);
      expect(wide.box!.contains(raanana.point), isTrue);
    });

    test('"Near me" has no "City only"', () {
      final area = NearMeArea(point: raananaSpot, radius: ParkRadius.cityOnly);
      expect(area.radius, ParkRadius.km10);
      expect(area.withRadius(ParkRadius.km25).radius, ParkRadius.km25);
    });
  });

  group('listing', () {
    final parks = FakeParksRepository.demoParks();
    DogPark byId(String id) => parks.firstWhere((p) => p.id == id);

    test('nearest first, inside the radius only', () {
      final listing = buildListing(
        area: NearMeArea(point: raananaSpot),
        areaParks: parks,
        savedParks: const [],
        filters: const {},
      );
      final ids = listing.nearby.map((l) => l.park.id).toList();
      expect(ids.first, 'demo-raanana-ahuza');
      expect(ids, isNot(contains('demo-jlm-herzl')));
      expect(ids, contains('demo-kfarsaba-weizmann'));
      final distances = listing.nearby.map((l) => l.distanceM!).toList();
      expect(distances, orderedEquals([...distances]..sort()));
    });

    test('saved parks first, wherever they are, and not twice', () {
      final listing = buildListing(
        area: NearMeArea(point: raananaSpot),
        areaParks: parks,
        savedParks: [byId('demo-tlv-meir'), byId('demo-raanana-ahuza')],
        filters: const {},
      );
      expect(listing.saved.map((l) => l.park.id), [
        'demo-raanana-ahuza',
        'demo-tlv-meir',
      ]);
      expect(listing.saved.every((l) => l.saved), isTrue);
      expect(
        listing.nearby.map((l) => l.park.id),
        isNot(contains('demo-raanana-ahuza')),
      );
      expect(listing.all.first.park.id, 'demo-raanana-ahuza');
    });

    test('filters keep only parks known to have every chosen detail', () {
      final listing = buildListing(
        area: CityArea(
          israelRegion.localityByCode('raanana')!,
          radius: ParkRadius.km25,
        ),
        areaParks: parks,
        savedParks: const [],
        filters: const {ParkDetail.fenced, ParkDetail.smallDogs},
      );
      expect(listing.nearby.map((l) => l.park.id), [
        'demo-raanana-park',
        'demo-kfarsaba-garden',
      ]);
    });
  });

  group('models', () {
    test('a row from the database', () {
      final park = DogPark.fromRow({
        'id': 'p1',
        'source': 'member',
        'name_he': ' ',
        'street_en': 'Ahuza',
        'lat': '32.18',
        'lng': 34.87,
        'locality_code': 'raanana',
        'fenced': 'yes',
        'water': 'no',
        'shade': 'unknown',
        'status': 'closed',
      });
      expect(park.source, ParkSource.member);
      expect(park.nameHe, isNull, reason: 'blank is no name');
      expect(park.street('he'), 'Ahuza', reason: 'falls back to English');
      expect(park.point.lat, 32.18);
      expect(park.has, [ParkDetail.fenced]);
      expect(park.answer(ParkDetail.water), ParkAnswer.no);
      expect(park.answer(ParkDetail.benches), ParkAnswer.unknown);
      expect(park.isClosed, isTrue);
    });

    test('the review queue from the server', () {
      final queue = ParkReviewQueue.fromJson({
        'suggestions': [
          {
            'id': 's1',
            'kind': 'details',
            'park_id': 'p1',
            'changes': {'water': 'yes', 'closed': true, 'colour': 'x'},
            'created_at': '2026-10-09T10:00:00Z',
            'park': {'id': 'p1', 'lat': 32, 'lng': 34.8},
          },
          {
            'id': 's2',
            'kind': 'new_park',
            'name': 'Run',
            'lat': 32.1,
            'lng': 34.9,
            'location_kind': 'locality',
            'locality_code': 'raanana',
            'place_note': 'Behind the school',
            'changes': {},
            'created_at': '2026-10-09T11:00:00Z',
          },
        ],
        'parks': [
          {'id': 'p9', 'lat': 31, 'lng': 35, 'status': 'pending_review'},
        ],
      });
      expect(queue.count, 3);
      final details = queue.suggestions.first;
      expect(details.changes, {ParkDetail.water: ParkAnswer.yes});
      expect(details.closed, isTrue);
      expect(details.park?.id, 'p1');
      final fresh = queue.suggestions.last;
      expect(fresh.kind, SuggestionKind.newPark);
      expect(fresh.location, SuggestedLocation.locality);
      expect(queue.parks.single.status, ParkStatus.pendingReview);
    });

    test('suggestion changes as the server stores them', () {
      expect(
        suggestionChanges({ParkDetail.smallDogs: ParkAnswer.no}, closed: false),
        {'small_dogs': 'no', 'closed': false},
      );
      expect(suggestionChanges({ParkDetail.shade: ParkAnswer.yes}), {
        'shade': 'yes',
      });
    });
  });

  group('words', () {
    test('an unnamed park is named after its street, then plainly', () {
      final named = DogPark(
        id: 'a',
        point: raananaSpot,
        nameHe: 'גינת הפארק',
        nameEn: 'Park run',
      );
      final street = DogPark(
        id: 'b',
        point: raananaSpot,
        streetHe: 'אחוזה',
        streetEn: 'Ahuza',
        localityCode: 'raanana',
      );
      const bare = DogPark(id: 'c', point: GeoPoint(32, 34.8));
      expect(en.parkTitle(named, 'en'), 'Park run');
      expect(he.parkTitle(named, 'he'), 'גינת הפארק');
      expect(en.parkTitle(street, 'en'), 'Dog park · Ahuza');
      expect(en.parkFullName(street, 'en'), "Dog park · Ahuza, Ra'anana");
      expect(stripBidiMarks(he.parkTitle(street, 'he')), 'גינת כלבים · אחוזה');
      expect(en.parkTitle(bare, 'en'), 'Dog park');
    });

    test('distances in metres and kilometres', () {
      expect(en.distance(347, 'en'), '350 m');
      expect(en.distance(830, 'en'), '830 m');
      expect(en.distance(1640, 'en'), '1.6 km');
      expect(en.distance(12400, 'en'), '12 km');
    });
  });
}
