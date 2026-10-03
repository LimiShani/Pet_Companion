// HTTP helpers shared by the functions: CORS (the web preview calls the
// function from the browser), JSON responses, and the error shapes of the
// API contract.

export const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

export function json(status: number, body: unknown, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...extra },
  });
}

export type ApiError =
  | 'invalid_request'
  | 'unsupported_region'
  | 'rate_limited'
  | 'unavailable'
  | 'method_not_allowed'
  | 'unauthorized';

const STATUS: Record<ApiError, number> = {
  invalid_request: 400,
  unsupported_region: 400,
  rate_limited: 429,
  unavailable: 503,
  method_not_allowed: 405,
  unauthorized: 401,
};

/** `{"error": code}` (+ `detail` for 400s) with the matching status. */
export function errorResponse(error: ApiError, detail?: string): Response {
  const body: Record<string, string> = { error };
  if (detail !== undefined && error === 'invalid_request') body.detail = detail;
  const extra: Record<string, string> = error === 'rate_limited' ? { 'Retry-After': '600' } : {};
  return json(STATUS[error], body, extra);
}

/** The CORS preflight answer. */
export function preflight(): Response {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

/** Parses a JSON body; undefined when it is missing or not JSON. */
export async function readJson(req: Request): Promise<unknown> {
  try {
    const text = await req.text();
    if (text.length > 16_384) return undefined; // nothing legitimate is this big
    return text === '' ? undefined : JSON.parse(text);
  } catch (_e) {
    return undefined;
  }
}
