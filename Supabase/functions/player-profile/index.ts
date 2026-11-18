import { APP_ID, admin, authenticate, readBody, rateLimit, serve, text } from "../_shared/common.ts";

serve(async request => {
  const user = await authenticate(request);
  await rateLimit(user, "player-profile", 30);
  const body = await readBody(request);
  if (body.appid !== APP_ID) throw new Error("Application mismatch");
  const crewName = text(body.crewName, 32, "crew_name").trim();
  if (!crewName) throw new Error("Invalid crew name");
  const { error } = await admin.from("rivet_players").upsert({
    appid: APP_ID,
    player_id: user.id,
    crew_name: crewName,
    updated_at: new Date().toISOString(),
  }, { onConflict: "appid,player_id" });
  if (error) throw new Error("Profile update failed");
  return { updated: true };
});
