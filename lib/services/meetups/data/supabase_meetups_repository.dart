import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../models/pet.dart';
import '../../../platform/session.dart';
import '../../community/data/community_models.dart' show ReportReason;
import '../../outdoors/data/park_models.dart';
import 'meetup_models.dart';
import 'meetups_repository.dart';

/// [MeetupsRepository] on `supabase/migrations/0028_meetups.sql`: reads
/// the `community_meetup_board` view (the reader's rights: open ads,
/// one's own, never a blocked member's or a reported one), writes through
/// the `meetup_*` functions, reports into `community_meetup_reports`, and
/// keeps "Tell me about new meetups here" in `dog_park_favorites`.
class SupabaseMeetupsRepository implements MeetupsRepository {
  SupabaseMeetupsRepository(this._backend);

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  /// More than any area holds at once (5 open ads per member).
  static const _limit = 300;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on MeetupException {
      rethrow;
    } on StaleSessionException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      throw MeetupException(failureOf(e.message, e.code));
    } catch (_) {
      throw const MeetupException(MeetupFailure.unavailable);
    }
  }

  /// The failure the server's refusal names (the functions of 0028 raise
  /// these words).
  static MeetupFailure failureOf(String message, String? code) {
    final text = message.toLowerCase();
    if (text.contains('rate_limited')) return MeetupFailure.rateLimited;
    if (text.contains('too_many_open')) return MeetupFailure.tooManyOpen;
    if (text.contains('not_open')) return MeetupFailure.notOpen;
    if (text.contains('blocked')) return MeetupFailure.blocked;
    if (text.contains('invalid_meetup') || code == '22023' || code == '22P02') {
      return MeetupFailure.invalid;
    }
    return MeetupFailure.other;
  }

  String get _now => DateTime.now().toUtc().toIso8601String();

  sb.PostgrestFilterBuilder<List<Map<String, dynamic>>> get _open => _client
      .from('community_meetup_board')
      .select()
      .eq('status', 'open')
      .eq('hidden', false)
      .gt('expires_at', _now);

  Future<List<Meetup>> _rows(
    sb.PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
  ) async {
    final rows = await query
        .order('created_at', ascending: false)
        .limit(_limit);
    return [for (final row in rows) meetupFromRow(row)];
  }

  @override
  bool get isDemo => false;

  @override
  Future<List<Meetup>> openMeetups(Iterable<String> localityCodes) =>
      _guard(() async {
        final codes = localityCodes.toList();
        if (codes.isEmpty) return const [];
        return _rows(_open.inFilter('locality_code', codes));
      });

  @override
  Future<List<Meetup>> atParks(Iterable<String> parkIds) => _guard(() async {
    final ids = parkIds.toList();
    if (ids.isEmpty) return const [];
    return _rows(_open.inFilter('park_id', ids));
  });

  @override
  Future<List<Meetup>> byAuthor(String authorId) =>
      _guard(() => _rows(_open.eq('author_id', authorId)));

  @override
  Future<List<Meetup>> mine() => _guard(() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const [];
    return _rows(
      _client.from('community_meetup_board').select().eq('author_id', me),
    );
  });

  @override
  Future<Meetup?> meetup(String id) => _guard(() async {
    final row = await _client
        .from('community_meetup_board')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : meetupFromRow(row);
  });

  @override
  Future<String> save(MeetupDraft draft, {String? id}) => _guard(() async {
    final result = await _client.rpc(
      'meetup_save',
      params: {'p_id': id, 'p': draftJson(draft)},
    );
    return '$result';
  });

  @override
  Future<void> close(String id) =>
      _guard(() => _client.rpc('meetup_close', params: {'p_id': id}));

  @override
  Future<void> renew(String id) =>
      _guard(() => _client.rpc('meetup_renew', params: {'p_id': id}));

  @override
  Future<int> answer(String id) => _guard(() async {
    final count = await _client.rpc('meetup_answer', params: {'p_id': id});
    return (count as num?)?.toInt() ?? 1;
  });

  @override
  Future<List<MeetupResponder>> responders(String id) => _guard(() async {
    final rows =
        (await _client.rpc('meetup_responders', params: {'p_id': id})
            as List?) ??
        const [];
    return [
      for (final row in rows.cast<Map>())
        MeetupResponder(
          id: '${row['user_id']}',
          name: '${row['display_name'] ?? ''}',
          answeredAt: DateTime.parse('${row['answered_at']}').toLocal(),
        ),
    ];
  });

  @override
  Future<void> report(String id, ReportReason reason) => _guard(
    () => _client.from('community_meetup_reports').insert({
      'meetup_id': id,
      'reason': reason.name,
    }),
  );

  @override
  Future<Set<String>> notifyParkIds() => _guard(() async {
    final rows = await _client
        .from('dog_park_favorites')
        .select('park_id')
        .eq('notify_meetups', true);
    return {for (final row in rows) '${row['park_id']}'};
  });

  @override
  Future<void> setNotify(String parkId, bool on) => _guard(
    () => _client
        .from('dog_park_favorites')
        .update({'notify_meetups': on})
        .eq('park_id', parkId),
  );
}

/// What `meetup_save` receives for [draft] ("now": a going-out-now ad,
/// 0035).
Map<String, Object?> draftJson(MeetupDraft draft) => {
  'kind': draft.kind.name,
  if (draft.time is NowTime) 'now': true,
  'pet_id': draft.pet?.petId,
  'park_id': draft.parkId,
  'locality_code': draft.parkId == null ? draft.localityCode : draft.city,
  'place_text': draft.parkId == null ? draft.placeText?.trim() : null,
  ...switch (draft.time) {
    OneOffTime(:final start, :final end) => {
      'starts_at': start.toUtc().toIso8601String(),
      'ends_at': end.toUtc().toIso8601String(),
    },
    RecurringTime(:final weekdays, :final part) => {
      'weekdays': (weekdays.toList()..sort()),
      'day_part': part.name,
    },
  },
  'suits': [for (final size in PetSize.values) if (draft.suits.contains(size)) size.name],
  'note': draft.note.trim(),
};

/// An ad from a `community_meetup_board` row.
Meetup meetupFromRow(Map row) {
  DateTime? time(Object? value) =>
      value == null ? null : DateTime.parse('$value').toLocal();
  String? text(Object? value) {
    final t = value == null ? '' : '$value'.trim();
    return t.isEmpty ? null : t;
  }

  final start = time(row['starts_at']);
  final end = time(row['ends_at']);
  final petName = text(row['pet_name']);
  final parkId = text(row['park_id']);
  // 0035's "going out now" kinds: walk_now, play_now.
  final kind = '${row['kind']}';
  final goingNow = kind.endsWith('_now');
  return Meetup(
    id: '${row['id']}',
    authorId: '${row['author_id']}',
    authorName: '${row['author_name'] ?? ''}',
    kind: kind.startsWith('play') ? MeetupKind.play : MeetupKind.walk,
    pet: petName == null
        ? null
        : MeetupPet(
            petId: text(row['pet_id']),
            name: petName,
            species: PetSpecies.fromName(text(row['pet_species'])),
            breed: text(row['pet_breed']),
            bornOn: text(row['pet_born_on']) == null
                ? null
                : DateTime.parse('${row['pet_born_on']}'),
            bornApprox: row['pet_born_approx'] == true,
            size: PetSize.parse(row['pet_size']),
            iconKey: text(row['pet_icon']),
          ),
    parkId: parkId,
    park: parkId == null || row['park_lat'] == null
        ? null
        : DogPark.fromRow({
            'id': parkId,
            'source': row['park_source'],
            'name_he': row['park_name_he'],
            'name_en': row['park_name_en'],
            'street_he': row['park_street_he'],
            'street_en': row['park_street_en'],
            'lat': row['park_lat'],
            'lng': row['park_lng'],
            'locality_code': row['park_locality_code'],
            for (final detail in ParkDetail.values)
              detail.column: row['park_${detail.column}'],
            'status': row['park_status'],
          }),
    localityCode: '${row['locality_code']}',
    placeText: text(row['place_text']),
    time: start != null && end != null
        ? (goingNow ? NowTime(start, end) : OneOffTime(start, end))
        : RecurringTime(
            {for (final d in (row['weekdays'] as List? ?? const [])) (d as num).toInt()},
            DayPart.values.asNameMap()['${row['day_part']}'] ?? DayPart.morning,
          ),
    suits: {
      for (final s in (row['suits'] as List? ?? const [])) ?PetSize.parse(s),
    },
    note: '${row['note'] ?? ''}',
    status: row['status'] == 'closed' ? MeetupStatus.closed : MeetupStatus.open,
    answerCount: (row['answer_count'] as num?)?.toInt() ?? 0,
    hidden: row['hidden'] == true,
    answered: row['answered'] == true,
    createdAt: time(row['created_at']) ?? DateTime.now(),
    expiresAt: time(row['expires_at']) ?? DateTime.now(),
  );
}
