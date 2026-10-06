/** Evaluate the caller's policy through the caller-bound RPC. No unverified
 * JWT claims or user IDs from the request body are trusted. Public requests
 * use the service key without an auth user, so only the explicit public
 * emergency-search policy can allow them. Invalid supplied JWTs fail closed.
 */
export function createFeatureAuthorizer(options: { url: string; serviceKey: string; fetcher?: typeof fetch }) {
  const fetcher = options.fetcher ?? fetch;
  return async (request: Request, capability: string): Promise<boolean> => {
    try {
      const response = await fetcher(`${options.url}/rest/v1/rpc/can_use`, {
        method: 'POST',
        headers: { apikey: options.serviceKey, Authorization: request.headers.get('Authorization') ?? `Bearer ${options.serviceKey}`,
          'Content-Type': 'application/json' },
        body: JSON.stringify({ p_capability: capability }),
      });
      return response.ok && await response.json() === true;
    } catch (_) { return false; }
  };
}
