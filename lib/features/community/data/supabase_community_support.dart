import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'community_models.dart';

const _unreachable = CommunityException(
  'Cannot reach the community right now. Check your connection and try again.',
);

/// Turns whatever a Supabase call throws into a [CommunityException] with
/// copy that fits the app's tone.
CommunityException communityExceptionFrom(Object error) {
  if (error is CommunityException) return error;
  if (error is sb.PostgrestException) return CommunityException(_postgrestMessage(error));
  if (error is sb.StorageException) return CommunityException(_storageMessage(error));
  if (error is sb.AuthException) return const CommunityException('Please sign in again.');
  return _unreachable;
}

/// Runs [action], rethrowing any failure as a [CommunityException].
Future<T> guardCommunity<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw communityExceptionFrom(e);
  }
}

String _postgrestMessage(sb.PostgrestException e) {
  final message = e.message.toLowerCase();
  switch (e.code) {
    case '42501': // row level security said no
      return 'You are not allowed to do that.';
    case '23514': // a check constraint (length limits)
      return 'That text is empty or too long.';
    case '23503': // the post or room was deleted meanwhile
      return 'This is no longer available.';
    case '42P01' || 'PGRST205': // 0003_community.sql has not been run
      return 'The community is not set up on the server yet.';
    case 'PGRST301' || 'PGRST303':
      return 'Please sign in again.';
  }
  if (message.contains('jwt')) return 'Please sign in again.';
  if (message.contains('failed host lookup') || message.contains('socket') || message.contains('network')) {
    return _unreachable.message;
  }
  return 'Something went wrong. Please try again.';
}

String _storageMessage(sb.StorageException e) {
  final message = e.message.toLowerCase();
  if (e.statusCode == '413' || message.contains('exceeded the maximum') || message.contains('too large')) {
    return 'That photo is too large. Please choose a smaller one.';
  }
  if (message.contains('mime type')) return 'Please choose a JPEG, PNG or WebP photo.';
  if (e.statusCode == '403' || message.contains('row-level security')) return 'You are not allowed to do that.';
  return 'The photo could not be uploaded. Please try again.';
}

/// Display names of community members, read from `public.profiles` and
/// remembered for the life of the repository.
class ProfileNames {
  ProfileNames(this._client);

  final sb.SupabaseClient _client;
  final _names = <String, String>{};

  /// Remembers a name that is already known (the signed-in user's own).
  void remember(String userId, String displayName) => _names[userId] = authorNameOrFallback(displayName);

  /// The name to show for each of [userIds]; members without one get the
  /// friendly fallback.
  Future<Map<String, String>> resolve(Iterable<String> userIds) async {
    final missing = userIds.toSet().difference(_names.keys.toSet()).toList();
    if (missing.isNotEmpty) {
      final rows = await _client.from('profiles').select('id, display_name').inFilter('id', missing);
      for (final row in rows) {
        _names[row['id'] as String] = authorNameOrFallback(row['display_name'] as String?);
      }
      // No profile row: do not ask again on every message.
      for (final id in missing) {
        _names.putIfAbsent(id, () => fallbackAuthorName);
      }
    }
    return {for (final id in userIds) id: _names[id] ?? fallbackAuthorName};
  }
}

/// Supabase returns UTC timestamps; the UI shows local time.
DateTime parseTimestamp(Object? value) => DateTime.parse(value as String).toLocal();
