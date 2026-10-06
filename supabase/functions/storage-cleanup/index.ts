import { createStorageCleanupHandler } from '../_shared/storage_cleanup_handler.ts';

// Invoke from a server-owned schedule. Maintenance remains active when
// product features are disabled, and no worker secret ships in the app.
Deno.serve(createStorageCleanupHandler({
  url: Deno.env.get('SUPABASE_URL') ?? '',
  key: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  secret: Deno.env.get('PETLOOP_CLEANUP_SECRET') ?? '',
}));
