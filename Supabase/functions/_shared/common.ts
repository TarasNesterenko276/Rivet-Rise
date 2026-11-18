import { createClient, type User } from "npm:@supabase/supabase-js@2.57.4";

export const APP_ID = "com.rivetrise.game18";
const supabaseURL = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

if (!supabaseURL || !serviceKey) throw new Error("Supabase server configuration is missing");

export const admin = createClient(supabaseURL, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

export class Failure extends Error {
  constructor(readonly status: number, readonly code: string) { super(code); }
}

export async function authenticate(request: Request): Promise<User> {
  const bearer = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!bearer) throw new Failure(401, "authentication_required");
  const { data, error } = await admin.auth.getUser(bearer);
  if (error || !data.user) throw new Failure(401, "invalid_session");
  return data.user;
}

export async function readBody(request: Request): Promise<Record<string, unknown>> {
  if (request.method !== "POST") throw new Failure(405, "post_required");
  const raw = await request.arrayBuffer();
  if (raw.byteLength > 16_384) throw new Failure(413, "request_too_large");
  let value: unknown;
  try { value = JSON.parse(new TextDecoder().decode(raw)); }
  catch { throw new Failure(400, "invalid_json"); }
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Failure(400, "invalid_body");
  return value as Record<string, unknown>;
}

export function text(value: unknown, max: number, field: string): string {
  if (typeof value !== "string" || value.length > max || /[\u0000-\u001f\u007f]/.test(value)) {
    throw new Failure(400, `invalid_${field}`);
  }
  return value;
}

export function uuid(value: unknown, field: string): string {
  const result = text(value, 36, field);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(result)) {
    throw new Failure(400, `invalid_${field}`);
  }
  return result;
}

export async function rateLimit(user: User, bucket: string, limit: number): Promise<void> {
  const { data, error } = await admin.rpc("rivet_consume_rate_limit", {
    p_player_id: user.id,
    p_bucket: bucket,
    p_limit: limit,
    p_window_seconds: 300,
  });
  if (error) throw new Failure(503, "rate_limit_unavailable");
  if (data !== true) throw new Failure(429, "too_many_requests");
}

export function serve(handler: (request: Request) => Promise<unknown>): void {
  Deno.serve(async request => {
    try {
      const data = await handler(request);
      return Response.json(data, { headers: { "Cache-Control": "no-store" } });
    } catch (error) {
      const failure = error instanceof Failure ? error : new Failure(503, "service_unavailable");
      if (!(error instanceof Failure)) console.error("Rivet Rise function failed", error?.constructor?.name ?? "Error");
      return Response.json({ error: failure.code }, {
        status: failure.status,
        headers: { "Cache-Control": "no-store" },
      });
    }
  });
}

export function appID(body: Record<string, unknown>): void {
  if (body.appid !== APP_ID) throw new Failure(403, "application_not_allowed");
}

export function currentISOWeek(date = new Date()): string {
  const day = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const weekday = (day.getUTCDay() + 6) % 7;
  day.setUTCDate(day.getUTCDate() - weekday + 3);
  const firstThursday = new Date(Date.UTC(day.getUTCFullYear(), 0, 4));
  const firstWeekday = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstWeekday + 3);
  const week = 1 + Math.round((day.getTime() - firstThursday.getTime()) / 604_800_000);
  return `${day.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}
