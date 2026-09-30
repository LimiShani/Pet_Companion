import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'community_models.dart';

/// Turns whatever a Supabase call throws into a [CommunityException] that
/// names the reason; the screen words it in its own language. The backend's
/// own explanation is kept as the exception's detail, for logs.
CommunityException communityExceptionFrom(Object error) {
  if (error is CommunityException) return error;
  if (error is sb.PostgrestException) return CommunityException(_postgrestFailure(error), error.message);
  if (error is sb.StorageException) return CommunityException(_storageFailure(error), error.message);
  if (error is sb.AuthException) return CommunityException(CommunityFailure.signInAgain, error.message);
  return CommunityException(CommunityFailure.offline, '$error');
}

/// Runs [action], rethrowing any failure as a [CommunityException].
Future<T> guardCommunity<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw communityExceptionFrom(e);
  }
}

CommunityFailure _postgrestFailure(sb.PostgrestException e) {
  final message = e.message.toLowerCase();
  switch (e.code) {
    case '42501': // row level security said no
      return CommunityFailure.notAllowed;
    case '23514': // a check constraint (length limits)
      return CommunityFailure.textInvalid;
    case '23503': // the post or room was deleted meanwhile
      return CommunityFailure.gone;
    case '42P01' || 'PGRST205': // 0003_community.sql has not been run
      return CommunityFailure.notSetUp;
    case 'PGRST301' || 'PGRST303':
      return CommunityFailure.signInAgain;
  }
  if (message.contains('jwt')) return CommunityFailure.signInAgain;
  if (message.contains('failed host lookup') || message.contains('socket') || message.contains('network')) {
    return CommunityFailure.offline;
  }
  return CommunityFailure.unknown;
}

CommunityFailure _storageFailure(sb.StorageException e) {
  final message = e.message.toLowerCase();
  if (e.statusCode == '413' || message.contains('exceeded the maximum') || message.contains('too large')) {
    return CommunityFailure.photoTooLarge;
  }
  if (message.contains('mime type')) return CommunityFailure.photoUnsupported;
  if (e.statusCode == '403' || message.contains('row-level security')) return CommunityFailure.notAllowed;
  return CommunityFailure.photoUpload;
}

/// Display names of community members, read from `public.profiles` and
/// remembered for the life of the repository. A member without a name is
/// an empty string: the screen shows its own fallback for it.
class ProfileNames {
  ProfileNames(this._client);

  final sb.SupabaseClient _client;
  final _names = <String, String>{};

  /// Remembers a name that is already known (the signed-in user's own).
  void remember(String userId, String displayName) => _names[userId] = storedAuthorName(displayName);

  /// The name of each of [userIds], as stored.
  Future<Map<String, String>> resolve(Iterable<String> userIds) async {
    final missing = userIds.toSet().difference(_names.keys.toSet()).toList();
    if (missing.isNotEmpty) {
      final rows = await _client.from('profiles').select('id, display_name').inFilter('id', missing);
      for (final row in rows) {
        _names[row['id'] as String] = storedAuthorName(row['display_name'] as String?);
      }
      // No profile row: do not ask again on every message.
      for (final id in missing) {
        _names.putIfAbsent(id, () => '');
      }
    }
    return {for (final id in userIds) id: _names[id] ?? ''};
  }
}

/// Supabase returns UTC timestamps; the UI shows local time.
DateTime parseTimestamp(Object? value) => DateTime.parse(value as String).toLocal();
