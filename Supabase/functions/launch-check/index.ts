import { admin, serve, text } from "../_shared/common.ts";

serve(async request => {
  if (request.method !== "GET") return { targetUrl: "blocked" };
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!secret || supplied !== secret) return { targetUrl: "blocked" };
  const appid = text(new URL(request.url).searchParams.get("appid"), 200, "appid");
  const { data, error } = await admin.rpc("rivet_read_launch_route", { p_appid: appid });
  if (error || typeof data !== "string") return { targetUrl: "blocked" };
  if (data === "blocked" || data === "resolve") return { targetUrl: data };
  try {
    const url = new URL(data);
    if (url.protocol === "https:" && !url.username && !url.password) return { targetUrl: url.href };
  } catch { /* invalid route is treated as blocked */ }
  return { targetUrl: "blocked" };
});
