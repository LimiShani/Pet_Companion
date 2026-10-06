import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../platform/storage_cleanup.dart';
import 'community_models.dart';

/// Turns whatever a Supabase call throws into a [CommunityException] that
/// names the reason; the screen words it in its own language. The backend's
/// own explanation is kept as the exception's detail, for logs.
CommunityException communityExceptionFrom(Object error) {
  if (error is CommunityException) return error;
  if (error is sb.PostgrestException) {
    return CommunityException(_postgrestFailure(error), error.message);
  }
  if (error is sb.StorageException) {
    return CommunityException(_storageFailure(error), error.message);
  }
  if (error is sb.AuthException) {
    return CommunityException(CommunityFailure.signInAgain, error.message);
  }
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
  // 0021_community_chat_safety.sql refuses a burst of posts, comments or
  // messages with this message.
  if (message.contains('rate_limited')) return CommunityFailure.slowDown;
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
  if (message.contains('failed host lookup') ||
      message.contains('socket') ||
      message.contains('network')) {
    return CommunityFailure.offline;
  }
  return CommunityFailure.unknown;
}

CommunityFailure _storageFailure(sb.StorageException e) {
  final message = e.message.toLowerCase();
  if (e.statusCode == '413' ||
      message.contains('exceeded the maximum') ||
      message.contains('too large')) {
    return CommunityFailure.photoTooLarge;
  }
  if (message.contains('mime type')) return CommunityFailure.photoUnsupported;
  if (e.statusCode == '403' || message.contains('row-level security')) {
    return CommunityFailure.notAllowed;
  }
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
  void remember(String userId, String displayName) =>
      _names[userId] = storedAuthorName(displayName);

  /// The name of each of [userIds], as stored.
  Future<Map<String, String>> resolve(Iterable<String> userIds) async {
    final missing = userIds.toSet().difference(_names.keys.toSet()).toList();
    if (missing.isNotEmpty) {
      final rows = await _client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', missing);
      for (final row in rows) {
        _names[row['id'] as String] = storedAuthorName(
          row['display_name'] as String?,
        );
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
DateTime parseTimestamp(Object? value) =>
    DateTime.parse(value as String).toLocal();

/// Photos of posts and chat messages, in the private `community-photos`
/// bucket under the author's folder. Links are signed and short-lived, and
/// remembered until shortly before they expire.
class CommunityPhotos {
  CommunityPhotos(this._client);

  final sb.SupabaseClient Function() _client;

  static const bucket = 'community-photos';

  /// How long a photo link stays valid.
  static const signedUrlSeconds = 6 * 60 * 60;

  static const contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  final _links = <String, ({String url, DateTime until})>{};

  /// Uploads [photo] into [authorId]'s folder and returns its path. The
  /// upload is registered with the storage clean-up first, so a photo whose
  /// post or message is never saved does not stay behind; call
  /// [attached] once the row that uses it exists.
  Future<String> upload(String authorId, PickedPhoto photo) async {
    final extension = extensionOf(photo);
    final path = '$authorId/${const Uuid().v4()}.$extension';
    final client = _client();
    await StorageCleanup(client).reserve(bucket, path);
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: sb.FileOptions(
            contentType: contentTypes[extension],
            cacheControl: '31536000',
          ),
        );
    return path;
  }

  /// The row using [path] is saved: the photo is no longer a candidate for
  /// clean-up. Best effort.
  Future<void> attached(String path) async {
    try {
      await StorageCleanup(_client()).attached(bucket, path);
    } catch (_) {}
  }

  /// Queues [path] for removal and runs the clean-up. Best effort.
  Future<void> remove(String path) async {
    try {
      final client = _client();
      await StorageCleanup(client).enqueue(bucket, path);
      await StorageCleanup(client).drain();
    } catch (_) {}
  }

  /// Signed links for [paths]. A failure here costs the pictures, not the
  /// list they are in.
  Future<Map<String, String>> links(Iterable<String> paths) async {
    final now = DateTime.now();
    final wanted = paths.toSet();
    final missing = [
      for (final path in wanted)
        if (_links[path] case final link when link == null || link.until.isBefore(now)) path,
    ];
    if (missing.isNotEmpty) {
      try {
        final results = await _client().storage
            .from(bucket)
            .createSignedUrlsResult(missing, signedUrlSeconds);
        // Renewed well before the link itself expires.
        final until = now.add(const Duration(seconds: signedUrlSeconds ~/ 2));
        for (final result in results) {
          if (result case sb.SignedUrlSuccess(:final path, :final signedUrl)) {
            _links[path] = (url: signedUrl, until: until);
          }
        }
      } catch (_) {}
    }
    return {
      for (final path in wanted)
        if (_links[path] case final link?) path: link.url,
    };
  }

  /// The file extension to store [photo] under: from its type, else its
  /// name. The picker re-encodes to JPEG, so that is the fallback.
  static String extensionOf(PickedPhoto photo) {
    final mime = photo.mimeType?.toLowerCase();
    for (final entry in contentTypes.entries) {
      if (entry.value == mime) return entry.key == 'jpeg' ? 'jpg' : entry.key;
    }
    final dot = photo.name.lastIndexOf('.');
    final extension = dot < 0
        ? ''
        : photo.name.substring(dot + 1).toLowerCase();
    if (contentTypes.containsKey(extension)) {
      return extension == 'jpeg' ? 'jpg' : extension;
    }
    if (extension.isEmpty && mime == null) return 'jpg';
    throw const CommunityException(CommunityFailure.photoUnsupported);
  }
}
