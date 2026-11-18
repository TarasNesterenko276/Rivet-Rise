const SETTINGS = Object.freeze({
  WEBSITE_SUPPORT_EMAIL: "TarasNesterenko276@icloud.com",
  BANDA_CLICK_URL: "https://banda-track-api.space/api/click-ios",
  BANDA_202_IS_PERMANENT_BLOCK: true,
  CLIENT_IP_HEADER: "X-Client-IP",
  CLIENT_IP_MAX_LENGTH: 45,
  UPSTREAM_TIMEOUT_MS: 30_000,
  MAX_RESPONSE_BYTES: 16_384,
  MAX_CHECK_REQUEST_BYTES: 16_384,
  MAX_ADJUST_JSON_BYTES: 8_192,
  MAX_DEEPLINK_LENGTH: 4_096,
  MAX_TARGET_URL_LENGTH: 4_096,
  PARAMETER_LIMITS: [200, 36, 200, 4_096, 4_096, 64],
});

const utf8 = new TextEncoder();
class Failure extends Error {
  constructor(status, code) { super(code); this.status = status; }
}
const json = (body, status = 200) => Response.json(body, {
  status,
  headers: { "Cache-Control": "no-store" },
});

function destination(value) {
  if (typeof value !== "string" || !value || value.length > SETTINGS.MAX_TARGET_URL_LENGTH || value !== value.trim()) {
    throw new Failure(502, "invalid_destination");
  }
  let url;
  try { url = new URL(value); } catch { throw new Failure(502, "invalid_destination"); }
  if (url.protocol !== "https:" || url.username || url.password || !url.hostname) {
    throw new Failure(502, "destination_not_allowed");
  }
  return url.href;
}

async function readBody(response) {
  const reader = response.body?.getReader();
  if (!reader) throw new Failure(502, "empty_response");
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > SETTINGS.MAX_RESPONSE_BYTES) {
        await reader.cancel();
        throw new Failure(502, "oversized_response");
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } finally {
    reader.releaseLock();
  }
}

async function check(request, env) {
  if (request.method !== "POST") throw new Failure(405, "post_required");
  const expected = env.CHECK_API_KEY || "";
  const supplied = request.headers.get("X-Check-API-Key") || "";
  if (!expected) throw new Failure(503, "check_not_configured");
  const hashes = await Promise.all([expected, supplied].map(value =>
    crypto.subtle.digest("SHA-256", utf8.encode(value))));
  const a = new Uint8Array(hashes[0]);
  const b = new Uint8Array(hashes[1]);
  if (a.reduce((diff, value, index) => diff | (value ^ b[index]), 0) !== 0) {
    throw new Failure(401, "unauthorized");
  }

  const requestBytes = await request.arrayBuffer();
  if (requestBytes.byteLength > SETTINGS.MAX_CHECK_REQUEST_BYTES) throw new Failure(413, "request_too_large");
  let params;
  try { params = JSON.parse(new TextDecoder().decode(requestBytes)); }
  catch { throw new Failure(400, "invalid_json"); }
  if (!params || typeof params !== "object" || Array.isArray(params)) throw new Failure(400, "invalid_parameters");

  const required = ["appid", "idfv", "deviceName", "pushToken", "userAgent"];
  const allowed = [...required, "appVersion", "adjust", "deeplink"];
  if (Object.keys(params).some(key => !allowed.includes(key)) ||
      required.some(key => typeof params[key] !== "string") ||
      (params.appVersion !== undefined && typeof params.appVersion !== "string") ||
      (params.deeplink !== undefined && typeof params.deeplink !== "string")) {
    throw new Failure(400, "invalid_parameters");
  }
  const values = [...required.map(key => params[key]), params.appVersion || ""];
  if (values.some((value, index) => value.length > SETTINGS.PARAMETER_LIMITS[index] || /[\u0000-\u001f\u007f]/.test(value))) {
    throw new Failure(400, "invalid_parameters");
  }
  const adjust = params.adjust === undefined ? {} : params.adjust;
  if (!adjust || typeof adjust !== "object" || Array.isArray(adjust) ||
      utf8.encode(JSON.stringify(adjust)).byteLength > SETTINGS.MAX_ADJUST_JSON_BYTES) {
    throw new Failure(400, "invalid_adjust_attribution");
  }
  const deeplink = params.deeplink || "";
  if (deeplink.length > SETTINGS.MAX_DEEPLINK_LENGTH || /[\u0000-\u001f\u007f]/.test(deeplink)) {
    throw new Failure(400, "invalid_parameters");
  }
  const rawClientIP = (request.headers.get(SETTINGS.CLIENT_IP_HEADER) || "").trim();
  const clientIP = rawClientIP.length <= SETTINGS.CLIENT_IP_MAX_LENGTH && /^[0-9a-fA-F:.]+$/.test(rawClientIP)
    ? rawClientIP : "";
  const clickToken = env.BANDA_CLICK_TOKEN;
  if (!clickToken) throw new Failure(503, "upstream_not_configured");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), SETTINGS.UPSTREAM_TIMEOUT_MS);
  const requestID = crypto.randomUUID();
  const startedAt = Date.now();
  try {
    const response = await fetch(SETTINGS.BANDA_CLICK_URL, {
      method: "POST",
      redirect: "manual",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        Accept: "text/plain,application/json",
        "X-Click-Token": clickToken,
        "X-Config-Request-Id": requestID,
        "Idempotency-Key": requestID,
      },
      body: JSON.stringify({
        appId: params.appid,
        idfv: params.idfv,
        idfa: "",
        ip: clientIP,
        pushToken: params.pushToken,
        userAgent: params.userAgent,
        deviceName: params.deviceName,
        appVersion: params.appVersion || "",
        naming: JSON.stringify(adjust),
        deeplink,
        adjust,
      }),
    });
    if (response.status === 202) {
      await response.body?.cancel();
      if (SETTINGS.BANDA_202_IS_PERMANENT_BLOCK) return json({ targetUrl: "blocked" });
      throw new Failure(503, "upstream_pending");
    }
    if (!response.ok) {
      await response.body?.cancel();
      throw new Failure(502, "upstream_unavailable");
    }
    let payload = (await readBody(response)).trim();
    try { payload = JSON.parse(payload); } catch { /* upstream may return a plain URL */ }
    if (typeof payload === "string") return json({ targetUrl: destination(payload) });
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) throw new Failure(502, "invalid_response");
    const type = payload.type ?? (payload.status === "policy" ? "policy" : "offer");
    if (type === "policy") return json({ targetUrl: "blocked" });
    if (type !== "offer") throw new Failure(502, "invalid_response");
    return json({ targetUrl: destination(payload.url) });
  } catch (error) {
    if (controller.signal.aborted) throw new Failure(504, "upstream_timeout");
    if (error instanceof Failure) throw error;
    throw new Failure(503, "upstream_unavailable");
  } finally {
    clearTimeout(timer);
    console.info("Banda click completed", JSON.stringify({ requestID, elapsedMs: Date.now() - startedAt }));
  }
}

export default {
  async fetch(request, env) {
    try {
      const path = new URL(request.url).pathname;
      if (path === "/check") return await check(request, env);
      if (path === "/health" && request.method === "GET") {
        const ready = !!(env.CHECK_API_KEY && env.BANDA_CLICK_TOKEN);
        return json({ status: ready ? "ok" : "not_configured" }, ready ? 200 : 503);
      }
      if (env.ASSETS) return await env.ASSETS.fetch(request);
      return new Response("Not found", { status: 404 });
    } catch (error) {
      return json({ error: error instanceof Failure ? error.message : "internal_error" },
        error instanceof Failure ? error.status : 503);
    }
  },
};
