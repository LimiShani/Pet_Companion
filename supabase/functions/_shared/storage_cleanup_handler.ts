interface CleanupOptions {
  url: string;
  key: string;
  secret: string;
  fetcher?: typeof fetch;
  now?: () => Date;
}
interface CleanupJob { id: string; bucket: string; path: string }
const digest = async (value: string) => new Uint8Array(await crypto.subtle.digest(
  'SHA-256', new TextEncoder().encode(value)));

export function createStorageCleanupHandler(options: CleanupOptions) {
  const fetcher = options.fetcher ?? fetch;
  const headers = { apikey: options.key, Authorization: `Bearer ${options.key}`, 'Content-Type': 'application/json' };
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return new Response('', {status: 405});
    const provided = request.headers.get('Authorization')?.replace(/^Bearer /, '') ?? '';
    const [expected, actual] = await Promise.all([digest(options.secret), digest(provided)]);
    let mismatch = 0;
    for (let i=0;i<expected.length;i++) mismatch |= expected[i] ^ actual[i];
    if (!options.secret || !provided || mismatch) return new Response('', {status: 401});
    let jobs: CleanupJob[];
    try {
      const at = (options.now ?? (() => new Date()))().toISOString();
      const response = await fetcher(`${options.url}/rest/v1/storage_cleanup_jobs?select=*&not_before=lte.${encodeURIComponent(at)}&order=created_at&limit=100`, {headers});
      if (!response.ok) return new Response('', {status: 503});
      const value: unknown = await response.json();
      if (!Array.isArray(value)) return new Response('', {status: 503});
      jobs = value as CleanupJob[];
    } catch (_) { return new Response('', {status: 503}); }
    let completed = 0;
    for (const job of jobs) {
      try {
        const check = await fetcher(`${options.url}/rest/v1/rpc/cleanup_file_is_orphan`, {
          method: 'POST', headers, body: JSON.stringify({p_bucket: job.bucket, p_path: job.path}),
        });
        if (!check.ok) continue;
        const orphan: unknown = await check.json();
        if (orphan !== true && orphan !== false) continue;
        if (orphan) {
          const removal = await fetcher(`${options.url}/storage/v1/object/${encodeURIComponent(job.bucket)}`, {
            method: 'DELETE', headers, body: JSON.stringify({prefixes: [job.path]}),
          });
          if (!removal.ok) continue;
        }
        const acknowledgement = await fetcher(`${options.url}/rest/v1/storage_cleanup_jobs?id=eq.${encodeURIComponent(job.id)}`, {method:'DELETE', headers});
        if (acknowledgement.ok) completed++;
      } catch (_) { /* Keep the durable job for the next run. Never log file paths. */ }
    }
    return Response.json({completed});
  };
}
