import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/supabase_health_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// What the backend is asked, in order, and how it answers: deletes must
/// take the rows first and the files after, so a failure never leaves a
/// record or a pet whose files are gone.
class _Backend {
  final calls = <String>[];

  /// Paths sent to file storage for removal, one list per request.
  final removed = <List<String>>[];

  bool rowDeleteFails = false;
  bool fileRemovalFails = false;

  /// The `storage_path` values a select of `health_documents` returns.
  List<String> storedPaths = const ['u/p/r/scan.pdf'];

  late final client = sb.SupabaseClient(
    'https://test.supabase.co',
    'test-key',
    httpClient: MockClient(_answer),
    authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
  );

  Future<http.Response> _answer(http.Request request) async {
    final path = request.url.path;
    if (path.startsWith('/storage/v1/object/')) {
      calls.add('files');
      removed.add([for (final p in (jsonDecode(request.body) as Map)['prefixes'] as List) p as String]);
      if (fileRemovalFails) {
        return _json(request, {'statusCode': '500', 'error': 'Internal', 'message': 'storage down'}, 500);
      }
      return _json(request, [], 200);
    }
    final table = path.split('/').last;
    if (request.method == 'GET') {
      calls.add('read $table');
      return _json(request, [
        for (final p in storedPaths) {'storage_path': p},
      ], 200);
    }
    if (request.method == 'DELETE') {
      calls.add('delete $table');
      if (rowDeleteFails) return _json(request, {'code': 'XX000', 'message': 'database down'}, 500);
      return http.Response('', 204, request: request);
    }
    return http.Response('unexpected ${request.method} $path', 400, request: request);
  }

  static http.Response _json(http.Request request, Object body, int status) =>
      http.Response(jsonEncode(body), status, request: request, headers: {'content-type': 'application/json'});
}

const _recordId = '11111111-1111-4111-8111-111111111111';
const _petId = '22222222-2222-4222-8222-222222222222';

HealthDocument _document(String id, String path) => HealthDocument(
  id: id,
  petId: _petId,
  recordId: _recordId,
  fileName: 'scan.pdf',
  mimeType: 'application/pdf',
  sizeBytes: 10,
  storagePath: path,
);

void main() {
  late _Backend backend;
  late SupabaseHealthRepository repository;

  setUp(() {
    backend = _Backend();
    repository = SupabaseHealthRepository(backend.client);
  });

  group('deleting a record', () {
    test('removes its row first and its files after', () async {
      await repository.deleteRecord(_recordId);
      expect(backend.calls, ['read health_documents', 'delete health_events', 'files']);
      expect(backend.removed, [
        ['u/p/r/scan.pdf'],
      ]);
    });

    test('keeps every file when the row cannot be deleted', () async {
      backend.rowDeleteFails = true;
      await expectLater(repository.deleteRecord(_recordId), throwsA(isA<HealthException>()));
      expect(backend.calls, ['read health_documents', 'delete health_events']);
      expect(backend.removed, isEmpty);
    });

    test('succeeds when only the files fail, and tries them again with the next removal', () async {
      backend.fileRemovalFails = true;
      await repository.deleteRecord(_recordId);

      backend.fileRemovalFails = false;
      await repository.deleteDocument(_document('d2', 'u/p/r/photo.jpg'));
      expect(backend.removed.last, unorderedEquals(['u/p/r/scan.pdf', 'u/p/r/photo.jpg']));

      // Removed now, so not sent again.
      await repository.deleteDocument(_document('d3', 'u/p/r/other.jpg'));
      expect(backend.removed.last, ['u/p/r/other.jpg']);
    });
  });

  group('deleting a document', () {
    test('removes its row first and its file after', () async {
      await repository.deleteDocument(_document('d1', 'u/p/r/scan.pdf'));
      expect(backend.calls, ['delete health_documents', 'files']);
    });

    test('keeps the file when the row cannot be deleted', () async {
      backend.rowDeleteFails = true;
      await expectLater(repository.deleteDocument(_document('d1', 'u/p/r/scan.pdf')), throwsA(isA<HealthException>()));
      expect(backend.removed, isEmpty);
    });
  });

  group("a pet's files", () {
    test('are only read while getting ready, and removed when asked after the pet is gone', () async {
      backend.storedPaths = ['u/p/r/a.pdf', 'u/p/r/b.jpg'];
      final removeFiles = await repository.prepareDeletingPet(_petId);
      expect(backend.calls, ['read health_documents']);
      expect(backend.removed, isEmpty);

      await removeFiles();
      expect(backend.removed, [
        ['u/p/r/a.pdf', 'u/p/r/b.jpg'],
      ]);
    });

    test('removing them never fails the delete the owner asked for', () async {
      final removeFiles = await repository.prepareDeletingPet(_petId);
      backend.fileRemovalFails = true;
      await removeFiles();
      expect(backend.calls.last, 'files');
    });
  });
}
