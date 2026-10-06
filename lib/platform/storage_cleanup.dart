import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller.dart';
import '../config/app_config.dart';

/// Core maintenance remains active even when the originating module is
/// removed or its user permission is revoked. Jobs are stored server-side.
class StorageCleanup {
  StorageCleanup(this.client);
  final SupabaseClient client;
  bool _working = false;

  Future<String> reserve(String bucket, String path) async =>
      await client.rpc(
            'queue_storage_cleanup',
            params: {'p_bucket': bucket, 'p_path': path, 'p_upload': true},
          )
          as String;

  Future<void> attached(String bucket, String path) async {
    await client
        .from('storage_cleanup_jobs')
        .delete()
        .eq('bucket', bucket)
        .eq('path', path);
  }

  Future<void> enqueue(String bucket, String path) async {
    await client.rpc(
      'queue_storage_cleanup',
      params: {'p_bucket': bucket, 'p_path': path},
    );
  }

  Future<void> drain() async {
    if (_working) return;
    final user = client.auth.currentUser?.id;
    if (user == null) return;
    _working = true;
    bool current() => client.auth.currentUser?.id == user;
    try {
      final jobs = await client
          .from('storage_cleanup_jobs')
          .select()
          .eq('owner_id', user)
          .lte('not_before', DateTime.now().toUtc().toIso8601String())
          .limit(50);
      for (final job in jobs) {
        if (!current()) return;
        try {
          final bucket = job['bucket'] as String;
          final path = job['path'] as String;
          final orphan =
              await client.rpc(
                'cleanup_file_is_orphan',
                params: {'p_bucket': bucket, 'p_path': path},
              ) ==
              true;
          if (!current()) return;
          if (orphan) await client.storage.from(bucket).remove([path]);
          if (!current()) return;
          await client
              .from('storage_cleanup_jobs')
              .delete()
              .eq('id', job['id']);
        } catch (_) {
          // Keep the durable job for the next session or the maintenance worker.
        }
      }
    } catch (_) {
      // An offline start must not block the app; the queue remains durable.
    } finally {
      _working = false;
    }
  }
}

final storageCleanupProvider = Provider<StorageCleanup?>(
  (ref) =>
      AppConfig.hasSupabase ? StorageCleanup(Supabase.instance.client) : null,
);

class StorageMaintenanceHost extends ConsumerStatefulWidget {
  const StorageMaintenanceHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<StorageMaintenanceHost> createState() =>
      _StorageMaintenanceHostState();
}

class _StorageMaintenanceHostState extends ConsumerState<StorageMaintenanceHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(storageCleanupProvider)?.drain();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next.value != null) ref.read(storageCleanupProvider)?.drain();
    });
    return widget.child;
  }
}
