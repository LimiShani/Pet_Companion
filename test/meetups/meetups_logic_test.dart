import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/community/community_words.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/community/data/community_models.dart';
import 'package:pet_companion/services/meetups/data/fake_meetups_repository.dart';
import 'package:pet_companion/services/meetups/data/meetup_models.dart';
import 'package:pet_companion/services/meetups/data/supabase_meetups_repository.dart';
import 'package:pet_companion/services/meetups/state/meetups_providers.dart';
import 'package:pet_companion/services/outdoors/data/park_area.dart';
import 'package:pet_companion/services/outdoors/data/park_models.dart';

/// Monday 12 October 2026, 09:00 (a made-up morning).
final monday = DateTime(2026, 10, 12, 9);

FakeMeetupsRepository fake({String viewer = 'demo', bool seed = true}) =>
    FakeMeetupsRepository(
      latency: Duration.zero,
      now: () => monday,
      viewerId: () => viewer,
      seed: seed,
    );

MeetupDraft walk({String? parkId = 'demo-raanana-park', String note = 'Hi'}) =>
    MeetupDraft(
      kind: MeetupKind.walk,
      time: const RecurringTime({1, 3}, DayPart.morning),
      pet: const MeetupPet(petId: 'kelly', name: 'Kelly', species: PetSpecies.dog),
      parkId: parkId,
      localityCode: parkId == null ? 'raanana' : null,
      placeText: parkId == null ? 'By the lake' : null,
      note: note,
    );

void main() {
  group('pet and time', () {
    test('a dog\'s size comes from its weight; other animals have none', () {
      expect(PetSize.of(PetSpecies.dog, 6), PetSize.small);
      expect(PetSize.of(PetSpecies.dog, 18), PetSize.medium);
      expect(PetSize.of(PetSpecies.dog, 30), PetSize.large);
      expect(PetSize.of(PetSpecies.dog, null), isNull);
      expect(PetSize.of(PetSpecies.cat, 4), isNull);
    });

    test('one-off and recurring times: today, this week, the next day', () {
      final oneOff = OneOffTime(DateTime(2026, 10, 17, 10), DateTime(2026, 10, 17, 12));
      expect(oneOff.occursOn(monday), isFalse);
      expect(oneOff.occursWithinWeek(monday), isTrue);
      expect(oneOff.nextDay(monday), DateTime(2026, 10, 17));
      final later = OneOffTime(DateTime(2026, 10, 25, 10), DateTime(2026, 10, 25, 11));
      expect(later.occursWithinWeek(monday), isFalse);
      const sundays = RecurringTime({7}, DayPart.noon);
      expect(sundays.occursOn(monday), isFalse);
      expect(sundays.nextDay(monday), DateTime(2026, 10, 18));
      expect(const RecurringTime({1}, DayPart.noon).occursOn(monday), isTrue);
    });

    test('the form\'s checks: a place, the hours, not over, days', () {
      expect(draftProblems(walk(), monday), isEmpty);
      expect(
        draftProblems(MeetupDraft(kind: MeetupKind.play, time: const RecurringTime({}, DayPart.noon)), monday),
        {MeetupDraftProblem.place, MeetupDraftProblem.days},
      );
      expect(
        draftProblems(
          MeetupDraft(
            kind: MeetupKind.play,
            parkId: 'p',
            time: OneOffTime(monday.subtract(const Duration(hours: 3)), monday.subtract(const Duration(hours: 1))),
          ),
          monday,
        ),
        {MeetupDraftProblem.past},
      );
      expect(
        draftProblems(MeetupDraft(kind: MeetupKind.play, parkId: 'p', time: OneOffTime(monday, monday.add(const Duration(hours: 13)))), monday),
        {MeetupDraftProblem.hours},
      );
      expect(draftProblems(walk(note: 'x' * 201), monday), {MeetupDraftProblem.note});
    });
  });

  group('area', () {
    test('City only asks for the city; a radius for every city in range', () {
      final raanana = localityOfCode('raanana')!;
      expect(MeetupsArea(raanana, ParkRadius.cityOnly).codes, ['raanana']);
      final near = MeetupsArea(raanana, ParkRadius.km10).codes;
      expect(near, containsAll(['raanana', 'kfar-saba', 'herzliya']));
      expect(near, isNot(contains('tel-aviv-yafo')));
      expect(MeetupsArea(raanana, ParkRadius.km25).codes, contains('tel-aviv-yafo'));
    });

    test('kept as a short key, and read back', () {
      final area = MeetupsArea(localityOfCode('kfar-saba')!, ParkRadius.km25);
      expect(area.key, 'kfar-saba|km25');
      expect(MeetupsArea.parse(area.key), area);
      expect(MeetupsArea.parse('nowhere|km10'), isNull);
    });

    test('a profile city in free text finds its locality, or nothing', () {
      expect(localityOfProfileCity('Tel Aviv')?.code, 'tel-aviv-yafo');
      expect(localityOfProfileCity(' רעננה ')?.code, 'raanana');
      expect(localityOfProfileCity('Tel'), isNull, reason: 'only a whole name');
      expect(localityOfProfileCity(''), isNull);
    });

    test('filters: kind, today, this week, recurring, my parks', () async {
      final ads = await fake().openMeetups(['raanana', 'kfar-saba', 'tel-aviv-yafo']);
      Set<String> ids(MeetupFilters f, {Set<String> parks = const {}}) => {
        for (final ad in ads)
          if (passesFilters(ad, f, monday, myParks: parks)) ad.id,
      };
      expect(ids(const MeetupFilters(kind: MeetupKind.play)), {'demo-meetup-maya', 'demo-meetup-priya'});
      expect(ids(const MeetupFilters(when: MeetupWhen.today)), {'demo-meetup-sam', 'demo-meetup-priya', 'demo-meetup-noa'});
      expect(ids(const MeetupFilters(when: MeetupWhen.recurring)), isNot(contains('demo-meetup-maya')));
      expect(ids(const MeetupFilters(when: MeetupWhen.thisWeek)), contains('demo-meetup-maya'));
      expect(ids(const MeetupFilters(atMyParks: true), parks: {'demo-tlv-meir'}), {'demo-meetup-priya'});
    });
  });

  group('the fake keeps the server\'s rules', () {
    test('sample ads: open ones by city, the demo\'s own, an ended one only in My ads', () async {
      final repo = fake();
      final tlv = await repo.openMeetups(['tel-aviv-yafo']);
      expect(tlv.map((a) => a.id), containsAll(['demo-meetup-priya', 'demo-meetup-noa', 'demo-meetup-jonas', 'demo-meetup-mine']));
      expect(tlv.map((a) => a.id), isNot(contains('demo-meetup-mine-ended')));
      final mine = await repo.mine();
      expect(mine.map((a) => a.id), ['demo-meetup-mine', 'demo-meetup-mine-ended']);
      expect(mine.first.answerCount, 2);
      expect(mine.last.hasEndedAt(monday), isTrue);
      expect((await repo.atParks(['demo-raanana-park'])).single.id, 'demo-meetup-sam');
      expect((await repo.byAuthor('u-maya')).single.pet?.name, 'Biscuit');
    });

    test('three new ads a day, five open at once', () async {
      final repo = fake();
      // The demo account has one open ad.
      await repo.save(walk());
      await repo.save(walk());
      await repo.save(walk());
      await expectLater(repo.save(walk()), throwsA(isA<MeetupException>().having((e) => e.failure, 'failure', MeetupFailure.rateLimited)));
      final later = FakeMeetupsRepository(latency: Duration.zero, now: () => monday.add(const Duration(days: 2)), seed: false)
        ..ads.addAll(repo.ads);
      await later.save(walk());
      await expectLater(later.save(walk()), throwsA(isA<MeetupException>().having((e) => e.failure, 'failure', MeetupFailure.tooManyOpen)));
    });

    test('a park gives the city; a removed or unknown park is refused; editing keeps the 30 days', () async {
      final repo = fake(seed: false);
      final id = await repo.save(walk());
      final ad = (await repo.meetup(id))!;
      expect(ad.localityCode, 'raanana');
      expect(ad.park?.id, 'demo-raanana-park');
      expect(ad.expiresAt, monday.add(const Duration(days: 30)));
      await expectLater(repo.save(walk(parkId: 'demo-kfarsaba-garden')), throwsA(isA<MeetupException>()), reason: 'closed for renovation');
      await repo.save(walk(note: 'Changed'), id: id);
      expect((await repo.meetup(id))!.note, 'Changed');
      expect((await repo.meetup(id))!.expiresAt, ad.expiresAt);
      final other = await repo.save(walk(parkId: null));
      expect((await repo.meetup(other))!.placeText, 'By the lake');
    });

    test('closing, renewing, editing what is closed', () async {
      final repo = fake();
      await repo.renew('demo-meetup-mine-ended');
      expect((await repo.meetup('demo-meetup-mine-ended'))!.isLiveAt(monday), isTrue);
      await repo.close('demo-meetup-mine');
      expect((await repo.meetup('demo-meetup-mine'))!.status, MeetupStatus.closed);
      await expectLater(repo.save(walk(), id: 'demo-meetup-mine'), throwsA(isA<MeetupException>().having((e) => e.failure, 'f', MeetupFailure.notOpen)));
      await expectLater(repo.close('demo-meetup-sam'), throwsA(isA<MeetupException>()), reason: 'not the demo\'s ad');
    });

    test('answers: counted once, never one\'s own, never across a block; the author\'s responders', () async {
      final repo = fake();
      expect(await repo.answer('demo-meetup-sam'), 2);
      expect(await repo.answer('demo-meetup-sam'), 2);
      expect((await repo.meetup('demo-meetup-sam'))!.answered, isTrue);
      await expectLater(repo.answer('demo-meetup-mine'), throwsA(isA<MeetupException>()));
      repo.blocks.add(('u-noa', 'demo'));
      await expectLater(repo.answer('demo-meetup-noa'), throwsA(isA<MeetupException>().having((e) => e.failure, 'f', MeetupFailure.blocked)));
      final responders = await repo.responders('demo-meetup-mine');
      expect(responders.map((r) => r.name), ['Sam', 'Maya']);
      repo.blocks.add(('demo', 'u-sam'));
      expect((await repo.responders('demo-meetup-mine')).map((r) => r.name), ['Maya']);
    });

    test('a reported ad leaves the reporter\'s board; three reports hide it', () async {
      final repo = fake();
      await repo.report('demo-meetup-sam', ReportReason.spam);
      expect(await repo.meetup('demo-meetup-sam'), isNull);
      repo.reports['demo-meetup-sam']!.addAll({'u-maya': ReportReason.spam, 'u-noa': ReportReason.abusive});
      await repo.report('demo-meetup-sam', ReportReason.spam);
      expect(repo.ads.firstWhere((a) => a.id == 'demo-meetup-sam').hidden, isTrue);
    });
  });

  group('Supabase rows', () {
    test('what meetup_save receives', () {
      final json = draftJson(
        MeetupDraft(
          kind: MeetupKind.play,
          pet: const MeetupPet(petId: 'p1', name: 'Lola', species: PetSpecies.dog),
          localityCode: 'raanana',
          placeText: ' By the lake ',
          time: OneOffTime(DateTime.utc(2026, 10, 17, 7), DateTime.utc(2026, 10, 17, 9)),
          suits: const {PetSize.large, PetSize.small},
          note: ' Hi ',
        ),
      );
      expect(json, {
        'kind': 'play',
        'pet_id': 'p1',
        'park_id': null,
        'locality_code': 'raanana',
        'place_text': 'By the lake',
        'starts_at': '2026-10-17T07:00:00.000Z',
        'ends_at': '2026-10-17T09:00:00.000Z',
        'suits': ['small', 'large'],
        'note': 'Hi',
      });
      expect(draftJson(walk())['weekdays'], [1, 3]);
      expect(draftJson(walk())['day_part'], 'morning');
    });

    test('a board row: the pet, the park, the times', () {
      final ad = meetupFromRow({
        'id': 'm1',
        'author_id': 'u1',
        'author_name': 'Ron',
        'kind': 'walk',
        'pet_name': 'Bonnie',
        'pet_species': 'dog',
        'pet_breed': 'Mixed',
        'pet_born_on': '2023-05-01',
        'pet_born_approx': true,
        'pet_size': 'medium',
        'park_id': 'p1',
        'park_name_en': 'Ahuza dog park',
        'park_lat': 32.186,
        'park_lng': 34.872,
        'park_fenced': 'yes',
        'park_status': 'active',
        'locality_code': 'raanana',
        'weekdays': [7, 1],
        'day_part': 'evening',
        'suits': ['small'],
        'note': 'Hello',
        'status': 'open',
        'answer_count': 2,
        'hidden': false,
        'answered': true,
        'created_at': '2026-10-10T08:00:00Z',
        'expires_at': '2026-11-09T08:00:00Z',
      });
      expect(ad.pet?.size, PetSize.medium);
      expect(ad.pet?.bornApprox, isTrue);
      expect(ad.park?.name('en'), 'Ahuza dog park');
      expect(ad.park?.has, [ParkDetail.fenced]);
      expect((ad.time as RecurringTime).weekdays, {7, 1});
      expect((ad.time as RecurringTime).part, DayPart.evening);
      expect(ad.suits, {PetSize.small});
      expect(ad.answered, isTrue);
      expect(ad.answerCount, 2);
    });

    test('the server\'s refusals', () {
      expect(SupabaseMeetupsRepository.failureOf('rate_limited', 'P0001'), MeetupFailure.rateLimited);
      expect(SupabaseMeetupsRepository.failureOf('too_many_open', 'P0001'), MeetupFailure.tooManyOpen);
      expect(SupabaseMeetupsRepository.failureOf('not_open', 'P0001'), MeetupFailure.notOpen);
      expect(SupabaseMeetupsRepository.failureOf('blocked', 'P0001'), MeetupFailure.blocked);
      expect(SupabaseMeetupsRepository.failureOf('invalid_meetup', '22023'), MeetupFailure.invalid);
      expect(SupabaseMeetupsRepository.failureOf('Meetups access required', '42501'), MeetupFailure.other);
    });
  });

  test('the queue of the moderators names a partner ad', () {
    expect(lookupCommunityL10n(englishLocale).moderationKind(ModerationKind.meetup), 'Partner ad');
    expect(lookupCommunityL10n(hebrewLocale).moderationKind(ModerationKind.meetup), 'מודעת שותפים');
  });
}
