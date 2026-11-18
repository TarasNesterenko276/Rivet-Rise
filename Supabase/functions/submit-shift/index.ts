import { APP_ID, Failure, admin, authenticate, currentISOWeek, readBody, rateLimit, serve, text, uuid } from "../_shared/common.ts";

serve(async request => {
  const user = await authenticate(request);
  await rateLimit(user, "submit-shift", 120);
  const body = await readBody(request);
  if (body.appid !== APP_ID) throw new Failure(403, "application_not_allowed");
  const submissionID = uuid(body.submissionID, "submission_id");
  const week = text(body.week, 8, "week");
  if (week !== currentISOWeek()) throw new Failure(400, "submission_week_not_current");
  const integer = (key: string, max: number) => {
    const value = body[key];
    if (!Number.isSafeInteger(value) || (value as number) < 0 || (value as number) > max) throw new Failure(400, `invalid_${key}`);
    return value as number;
  };
  const floors = integer("floors", 10_000);
  const score = integer("score", 2_000_000_000);
  const rivets = integer("rivets", 10_000);
  const perfects = integer("perfects", 10_000);
  const districts = integer("districts", 10_000);
  const duration = body.durationSeconds;
  if (typeof duration !== "number" || !Number.isFinite(duration) || duration < 0 || duration > 86_400) throw new Failure(400, "invalid_duration");
  const crewName = text(body.crewName, 32, "crew_name").trim();
  const foremanID = text(body.foremanID, 64, "foreman_id");
  if (!crewName || !foremanID) throw new Failure(400, "missing_player_fields");

  const { error } = await admin.rpc("rivet_submit_shift", {
    p_appid: APP_ID,
    p_player_id: user.id,
    p_crew_name: crewName,
    p_submission_id: submissionID,
    p_week: week,
    p_floors: floors,
    p_score: score,
    p_rivets: rivets,
    p_perfects: perfects,
    p_districts: districts,
    p_duration_seconds: duration,
    p_foreman_id: foremanID,
  });
  if (error) throw new Failure(503, "shift_submission_failed");
  return { accepted: true };
});
