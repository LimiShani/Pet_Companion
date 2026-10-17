import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/services/safety/data/fake_lost_alerts_repository.dart';
import 'package:pet_companion/services/safety/data/supabase_lost_alerts_repository.dart';
import 'package:pet_companion/services/safety/state/safety_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// Lost mode's repositories and controller: the server's rules as the fake
// keeps them, the refusals as the app words them.

final _now = DateTime(2026, 10, 17, 15, 0);

FakeLostAlertsRepository _fake({bool seeded = false}) => FakeLostAlertsRepository(
  latency: Duration.zero,
  now: () => _now,
  seeded: seeded,
  petFacts: (id) => (name: id == 'kelly' ? 'Kelly' : 'Soya', species: id == 'kelly' ? 'dog' : 'cat'),
);

LostStart _start(String petId, {String place = 'Ahuza park gate'}) => LostStart(
  petId: petId,
  localityCode: 'raanana',
  seenAt: _now.subtract(const Duration(hours: 1)),
  place: place,
  note: 'Shy, do not chase',
  language: 'en',
);

Future<Object?> _refusal(Future<Object?> Function() call) async {
  try {
    await call();
  } on LostAlertException catch (error) {
    return error.failure;
  }
  return null;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the fake keeps the server\'s rules', () {
    test('start, read, sightings, found', () async {
      final repo = _fake();
      final alert = await repo.start(_start('kelly'));
      expect(alert.isActive, isTrue);
      expect(alert.petName, 'Kelly');
      expect(alert.petSpecies, 'dog');
      expect(alert.lastSeenPlace, 'Ahuza park gate');
      expect(alert.postId, isNotNull);
      expect((await repo.mine()).single.id, alert.id);

      repo.addSighting(alert.id);
      repo.addSighting(alert.id);
      expect((await repo.mine()).single.sightings, 2);
      expect((await repo.near('raanana')).single.petName, 'Kelly');
      expect(await repo.near('haifa'), isEmpty);

      final found = await repo.markFound(alert.id);
      expect(found.status, LostAlertStatus.found);
      expect(found.closedAt, _now);
      expect(found.postId, isNotNull, reason: 'The answered post stays');
      expect(await repo.mine(), isEmpty);
      // Closing again changes nothing.
      expect((await repo.markFound(alert.id)).status, LostAlertStatus.found);
    });

    test('one open alert per pet, three a day, a valid request', () async {
      final repo = _fake();
      await repo.start(_start('kelly'));
      expect(await _refusal(() => repo.start(_start('kelly'))), LostAlertFailure.alreadyActive);
      expect(
        await _refusal(() => repo.start(_start('soya', place: 'x' * 121))),
        LostAlertFailure.invalid,
      );
      expect(
        await _refusal(
          () => repo.start(LostStart(petId: 'soya', localityCode: 'Ra anana', seenAt: _now)),
        ),
        LostAlertFailure.invalid,
      );
      final soya = await repo.start(_start('soya'));
      // A cancelled alert nobody answered loses its post.
      final cancelled = await repo.cancel(soya.id);
      expect(cancelled.status, LostAlertStatus.cancelled);
      expect(cancelled.postId, isNull);
      await repo.start(_start('soya'));
      expect(repo.alerts, hasLength(3));
      final open = (await repo.mine()).first;
      await repo.cancel(open.id);
      expect(await _refusal(() => repo.start(_start('soya'))), LostAlertFailure.rateLimited);
    });

    test('a neighbour\'s alert is seeded for the demo; every call can fail', () async {
      final repo = _fake(seeded: true);
      expect((await repo.near('tel-aviv-yafo')).single.petName, 'Mitzi');
      expect(await repo.mine(), isEmpty, reason: 'The demo pets are at home');
      repo.failing = true;
      expect(await _refusal(repo.mine), LostAlertFailure.unknown);
    });
  });

  test('the server\'s refusals read as failures', () {
    LostAlertFailure of(String message, [String? code]) =>
        SupabaseLostAlertsRepository.failureOf(sb.PostgrestException(message: message, code: code));
    expect(of('lost_active', 'P0001'), LostAlertFailure.alreadyActive);
    expect(of('rate_limited', 'P0001'), LostAlertFailure.rateLimited);
    expect(of('invalid_alert', '22023'), LostAlertFailure.invalid);
    expect(of('Safety access required', '42501'), LostAlertFailure.notAllowed);
    expect(of('timeout', '57014'), LostAlertFailure.unknown);
  });

  test('alerts parse from the server\'s JSON', () {
    final alert = LostAlert.fromJson({
      'id': 'a1',
      'pet_id': 'p1',
      'owner_id': 'u1',
      'pet_name': 'Kelly',
      'pet_species': 'dog',
      'locality_code': 'raanana',
      'last_seen_at': '2026-10-17T11:00:00Z',
      'last_seen_place': 'Park',
      'note': '',
      'language': 'he',
      'post_id': 'post1',
      'status': 'found',
      'created_at': '2026-10-17T11:05:00Z',
      'closed_at': '2026-10-17T13:00:00Z',
      'sightings': 3,
    });
    expect(alert.status, LostAlertStatus.found);
    expect(alert.isActive, isFalse);
    expect(alert.sightings, 3);
    expect(alert.lastSeenAt.toUtc(), DateTime.utc(2026, 10, 17, 11));
    final near = NearbyLostAlert.fromJson({
      'id': 'a1',
      'pet_name': 'Kelly',
      'pet_species': 'dog',
      'locality_code': 'raanana',
      'last_seen_at': '2026-10-17T11:00:00Z',
      'last_seen_place': 'Park',
      'post_id': 'post1',
      'created_at': '2026-10-17T11:05:00Z',
    });
    expect(near.postId, 'post1');
  });

  group('the controller', () {
    ProviderContainer container(FakeLostAlertsRepository repo, {bool allowed = true}) {
      final access = FakeAccessRepository();
      if (!allowed) {
        access.groups['standard']!.remove(SafetyCapabilities.view);
      }
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
          accessRepositoryProvider.overrideWithValue(access),
          lostAlertsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> signIn(ProviderContainer c) async {
      await c.read(authControllerProvider.future);
      await c.read(authControllerProvider.notifier).signIn(email: 'demo@petloop.app', password: 'kelly1234');
    }

    test('starts, shows the open alert of the pet, and closes it', () async {
      final repo = _fake();
      final c = container(repo);
      await signIn(c);
      expect(await c.read(lostAlertsProvider.future), isEmpty);
      expect(c.read(activeLostAlertProvider('kelly')), isNull);

      final alert = await c.read(lostAlertsProvider.notifier).start(_start('kelly'));
      expect(c.read(activeLostAlertProvider('kelly'))?.id, alert.id);
      expect(c.read(activeLostAlertProvider('soya')), isNull);

      await c.read(lostAlertsProvider.notifier).markFound(alert.id);
      expect(c.read(activeLostAlertProvider('kelly')), isNull);
    });

    test('without safety.view there are no alerts to read', () async {
      final repo = _fake();
      await repo.start(_start('kelly'));
      final c = container(repo, allowed: false);
      await signIn(c);
      expect(await c.read(lostAlertsProvider.future), isEmpty);
    });
  });
}
