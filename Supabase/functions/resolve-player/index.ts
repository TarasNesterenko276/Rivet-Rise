import { APP_ID, Failure, admin, authenticate, readBody, rateLimit, serve, text, uuid } from "../_shared/common.ts";

function webURL(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 4_096) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password || !url.hostname) return null;
    return url.href;
  } catch {
    return null;
  }
}

serve(async request => {
  const user = await authenticate(request);
  await rateLimit(user, "resolve-player", 30);
  const body = await readBody(request);
  if (body.appid !== APP_ID) return { action: "game", targetUrl: null, cacheable: false };

  const idfv = uuid(body.idfv, "idfv");
  const deviceName = text(body.deviceName, 200, "device_name");
  const pushToken = text(body.pushToken ?? "", 4_096, "push_token");
  const userAgent = text(body.userAgent, 4_096, "user_agent");
  const appVersion = text(body.appVersion ?? "", 64, "app_version");
  const deeplink = text(body.deeplink ?? "", 4_096, "deeplink");
  let adjust: unknown = body.adjust ?? {};
  if (body.adjust_json !== undefined) {
    try { adjust = JSON.parse(text(body.adjust_json, 8_192, "adjust_json")); }
    catch { throw new Failure(400, "invalid_adjust_attribution"); }
  }
  if (!adjust || typeof adjust !== "object" || Array.isArray(adjust) ||
      new TextEncoder().encode(JSON.stringify(adjust)).byteLength > 8_192) {
    return { action: "game", targetUrl: null, cacheable: false };
  }

  const { data: route, error: routeError } = await admin.rpc("rivet_read_launch_route", { p_appid: APP_ID });
  if (routeError || typeof route !== "string") return { action: "game", targetUrl: null, cacheable: false };
  if (route === "blocked") return { action: "game", targetUrl: null, cacheable: true };
  const fixedURL = webURL(route);
  if (fixedURL) return { action: "webview", targetUrl: fixedURL, cacheable: true };
  if (route !== "resolve") return { action: "game", targetUrl: null, cacheable: false };

  const checkURL = Deno.env.get("CHECK_URL");
  const checkKey = Deno.env.get("CHECK_API_KEY");
  if (!checkURL || !checkKey) return { action: "game", targetUrl: null, cacheable: false };
  let endpoint: URL;
  try { endpoint = new URL(checkURL); }
  catch { return { action: "game", targetUrl: null, cacheable: false }; }
  if (endpoint.protocol !== "https:" || endpoint.username || endpoint.password || endpoint.hash) {
    return { action: "game", targetUrl: null, cacheable: false };
  }

  const forwarded = request.headers.get("x-forwarded-for")?.split(",", 1)[0].trim() ?? "";
  const clientIP = forwarded.length <= 45 && /^[0-9a-fA-F:.]+$/.test(forwarded) ? forwarded : "";
  const identity = { p_appid: APP_ID, p_idfv: idfv };
  const { data: state, error: acquireError } = await admin.rpc("rivet_acquire_launch", identity);
  if (acquireError) throw new Failure(503, "launch_state_unavailable");
  if (state?.target === "blocked") return { action: "game", targetUrl: null, cacheable: true };
  const cached = webURL(state?.target);
  if (cached) return { action: "webview", targetUrl: cached, cacheable: true };
  if (!state?.lease) throw new Failure(503, "resolution_in_progress");

  const lease = { ...identity, p_lease: state.lease };
  let committed = false;
  try {
    const response = await fetch(endpoint, {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(32_000),
      headers: {
        "Content-Type": "application/json",
        "X-Check-API-Key": checkKey,
        "X-Client-IP": clientIP,
      },
      body: JSON.stringify({ appid: APP_ID, idfv, deviceName, pushToken, userAgent, appVersion, adjust, deeplink }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      console.warn("Launch checker returned HTTP status", response.status);
      throw new Failure(502, "launch_check_failed");
    }
    const data = await response.json();
    const target = data?.targetUrl === "blocked" ? "blocked" : webURL(data?.targetUrl);
    if (!target) throw new Failure(502, "invalid_launch_decision");
    const { data: saved, error } = await admin.rpc("rivet_finish_launch", { ...lease, p_target: target });
    if (error || saved !== true) throw new Failure(503, "launch_decision_not_saved");
    committed = true;
    return target === "blocked"
      ? { action: "game", targetUrl: null, cacheable: true }
      : { action: "webview", targetUrl: target, cacheable: true };
  } finally {
    if (!committed) await admin.rpc("rivet_finish_launch", { ...lease, p_target: null });
  }
});
