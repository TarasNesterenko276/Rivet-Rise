import { APP_ID, Failure, admin, authenticate, readBody, rateLimit, serve, text } from "../_shared/common.ts";

serve(async request => {
  const user = await authenticate(request);
  await rateLimit(user, "claim-reward", 20);
  const body = await readBody(request);
  if (body.appid !== APP_ID) throw new Failure(403, "application_not_allowed");
  const week = text(body.week, 8, "week");
  const slotID = text(body.slotID, 32, "slot_id");
  if (!/^[0-9]{4}-W[0-9]{2}$/.test(week)) throw new Failure(400, "invalid_week");
  const { data, error } = await admin.rpc("rivet_claim_weekly_reward", {
    p_appid: APP_ID,
    p_player_id: user.id,
    p_week: week,
    p_slot_id: slotID,
  });
  if (error) throw new Failure(409, "reward_not_claimable");
  return data;
});
