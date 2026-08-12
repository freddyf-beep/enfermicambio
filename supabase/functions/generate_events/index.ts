// generate_events: after a successful health sync, compute competition events
// for the syncing user and emit notifications: daily ranking overtakes,
// leader changes, step milestones, personal records and the daily goal.
//
// Auth: the caller's JWT or the per-user Health Auto Export bridge token. The
// body user_id must match the resolved identity; nobody can generate events on
// behalf of someone else. All emissions are idempotent via payload dedupe keys
// and rank_positions.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { createClient } from "@supabase/supabase-js";

const STEP_MILESTONES = [5000, 10000, 15000, 20000];

function bearerToken(req: Request): string | null {
  const authorization = req.headers.get("authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  const value = match?.[1]?.trim() ||
    req.headers.get("x-health-export-token")?.trim() || "";
  return value.length >= 32 && value.length <= 256 ? value : null;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function resolveUserId(
  supabaseAdmin: ReturnType<typeof createClient>,
  token: string,
): Promise<string | null> {
  const { data: userData } = await supabaseAdmin.auth.getUser(token);
  if (userData.user?.id) return userData.user.id;

  const tokenHash = await sha256Hex(token);
  const { data: bridgeRow } = await supabaseAdmin
    .from("health_ingestion_tokens")
    .select("user_id")
    .eq("token_hash", tokenHash)
    .eq("active", true)
    .maybeSingle();
  return (bridgeRow?.user_id as string | undefined) ?? null;
}

async function loadConfig(supabaseAdmin: ReturnType<typeof createClient>) {
  const { data, error } = await supabaseAdmin
    .from("app_config")
    .select("config_key, config_value");
  if (error) throw new Error(`config read failed: ${error.message}`);
  const map = new Map<string, unknown>();
  for (const row of data ?? []) map.set(row.config_key, row.config_value);
  return map;
}

function todayInCompetitionTz(tz: string): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

async function hasNotification(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  type: string,
  key: string,
): Promise<boolean> {
  const { data, error } = await supabaseAdmin
    .from("notifications")
    .select("id")
    .eq("user_id", userId)
    .eq("type", type)
    .eq("payload->>key", key)
    .limit(1);
  if (error) throw new Error(`notification lookup failed: ${error.message}`);
  return (data?.length ?? 0) > 0;
}

async function notify(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  type: string,
  title: string,
  body: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const { error } = await supabaseAdmin.rpc("insert_notification", {
    p_user_id: userId,
    p_type: type,
    p_title: title,
    p_body: body,
    p_payload: payload,
  });
  if (error) throw new Error(`notify failed: ${error.message}`);
}

export default {
  fetch: withSupabase(
    { auth: "none" },
    async (req, ctx) => {
      try {
        return await handle(ctx.supabaseAdmin, req);
      } catch (error) {
        return Response.json(
          { error: error instanceof Error ? error.message : String(error) },
          { status: 500 },
        );
      }
    },
  ),
};

async function handle(
  supabaseAdmin: ReturnType<typeof createClient>,
  req: Request,
  ): Promise<Response> {
  let body: { user_id?: string; date?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "invalid body" }, { status: 400 });
  }

  const token = bearerToken(req);
  if (!token) {
    return Response.json({ error: "unauthenticated" }, { status: 401 });
  }
  const userId = await resolveUserId(supabaseAdmin, token);
  if (!userId) {
    return Response.json({ error: "unauthenticated" }, { status: 401 });
  }
  if (!body.user_id || body.user_id !== userId) {
    return Response.json({ error: "forbidden" }, { status: 403 });
  }

  const config = await loadConfig(supabaseAdmin);
  const tz = (config.get("competition_timezone") as string) ?? "America/Santiago";
  const competitionDate = body.date ?? todayInCompetitionTz(tz);

  const { data: activity, error: actErr } = await supabaseAdmin
    .from("daily_activity")
    .select("user_id, daily_steps, manual_entry_detected")
    .eq("activity_date", competitionDate);
  if (actErr) throw new Error(`activity read failed: ${actErr.message}`);
  const rows = (activity ?? [])
    .filter((r) => !r.manual_entry_detected)
    .sort((a, b) =>
      b.daily_steps - a.daily_steps || a.user_id.localeCompare(b.user_id)
    );

  const emitted: string[] = [];

  // --- Ranking: overtakes + leader change --------------------------------
  const { data: prevPositions, error: prevErr } = await supabaseAdmin
    .from("rank_positions")
    .select("user_id, position")
    .eq("competition_date", competitionDate);
  if (prevErr) throw new Error(`rank read failed: ${prevErr.message}`);

  const prevMap = new Map<string, number>(
    (prevPositions ?? []).map((r) => [r.user_id as string, r.position as number]),
  );
  const newMap = new Map<string, number>();
  rows.forEach((row, index) => newMap.set(row.user_id as string, index + 1));

  const names = new Map<string, string>();
  const { data: profiles } = await supabaseAdmin
    .from("profiles")
    .select("id, display_name, daily_step_target");
  for (const p of profiles ?? []) {
    names.set(p.id as string, p.display_name as string);
  }

  for (const row of rows) {
    const uid = row.user_id as string;
    const newPos = newMap.get(uid)!;
    const prevPos = prevMap.get(uid);
    if (prevPos === undefined) continue; // first sighting: baseline only

    const stepsByUser = new Map(rows.map((r) => [r.user_id as string, r.daily_steps as number]));
    for (let pos = prevPos - 1; pos >= newPos; pos--) {
      if (pos < 1) continue;
      const loserId = rows[pos - 1]?.user_id as string | undefined;
      if (!loserId || loserId === uid) continue;
      const key = `overtake:${competitionDate}:${uid}:${loserId}`;
      if (await hasNotification(supabaseAdmin, loserId, "overtake", key)) {
        continue;
      }
      const gap = (stepsByUser.get(uid) ?? 0) - (stepsByUser.get(loserId) ?? 0);
      await notify(
        supabaseAdmin,
        loserId,
        "overtake",
        `${names.get(uid) ?? "Alguien"} te pasó`,
        `🚨 ${names.get(uid) ?? "Alguien"} te pasó por ${gap.toLocaleString("es-CL")} pasos.`,
        { key, actor_id: uid, competition_date: competitionDate },
      );
      emitted.push(`overtake:${loserId}`);
    }
  }

  const newLeader = rows[0]?.user_id as string | undefined;
  const prevLeader = rows.length > 0
    ? [...prevMap.entries()].sort((a, b) => a[1] - b[1])[0]?.[0]
    : undefined;
  if (newLeader && (!prevLeader || prevLeader !== newLeader)) {
    const key = `leader:${competitionDate}:${newLeader}`;
    if (!(await hasNotification(supabaseAdmin, newLeader, "leader_change", key))) {
      for (const p of profiles ?? []) {
        const pid = p.id as string;
        if (pid === newLeader) continue;
        await notify(
          supabaseAdmin,
          pid,
          "leader_change",
          `${names.get(newLeader) ?? "Alguien"} tomó el primer lugar`,
          `👑 ${names.get(newLeader) ?? "Alguien"} se puso al frente.`,
          { key, actor_id: newLeader, competition_date: competitionDate },
        );
      }
      emitted.push(`leader_change:${newLeader}`);
    }
    // Feed post, rate-limited by its own cooldown logic.
    const { error: feedErr } = await supabaseAdmin.rpc(
      "maybe_publish_leader_change",
      { p_date: competitionDate },
    );
    if (feedErr) throw new Error(`leader feed post failed: ${feedErr.message}`);
  }

  // --- Persist current positions -------------------------------------------
  const upserts = rows.map((row, index) => ({
    competition_date: competitionDate,
    user_id: row.user_id as string,
    position: index + 1,
  }));
  if (upserts.length > 0) {
    const { error: upErr } = await supabaseAdmin
      .from("rank_positions")
      .upsert(upserts, { onConflict: "competition_date,user_id" });
    if (upErr) throw new Error(`rank upsert failed: ${upErr.message}`);
  }

  // --- Personal events for the syncing user --------------------------------
  const myRow = rows.find((r) => r.user_id === userId);
  if (myRow) {
    const mySteps = myRow.daily_steps as number;
    const profile = (profiles ?? []).find((p) => p.id === userId);

    for (const milestone of STEP_MILESTONES) {
      if (mySteps < milestone) continue;
      const key = `steps:${milestone}:${competitionDate}`;
      if (await hasNotification(supabaseAdmin, userId, "steps_milestone", key)) {
        continue;
      }
      await notify(
        supabaseAdmin,
        userId,
        "steps_milestone",
        "¡Hito de pasos!",
        `🎉 ¡Llegaste a ${milestone.toLocaleString("es-CL")} pasos hoy!`,
        { key, milestone, competition_date: competitionDate },
      );
      emitted.push(`steps_milestone:${milestone}`);
    }

    const stepGoal = (profile?.daily_step_target as number) ??
      ((config.get("step_goal_default") as number) ?? 10000);
    if (mySteps >= stepGoal) {
      const key = `goal:${competitionDate}`;
      if (!(await hasNotification(supabaseAdmin, userId, "daily_goal", key))) {
        await notify(
          supabaseAdmin,
          userId,
          "daily_goal",
          "¡Meta cumplida!",
          `✅ Cumpliste tu meta de ${stepGoal.toLocaleString("es-CL")} pasos.`,
          { key, steps: mySteps, competition_date: competitionDate },
        );
        emitted.push("daily_goal");
      }
    }

    const { data: history, error: histErr } = await supabaseAdmin
      .from("daily_activity")
      .select("daily_steps")
      .eq("user_id", userId)
      .neq("activity_date", competitionDate)
      .order("daily_steps", { ascending: false })
      .limit(1);
    if (histErr) throw new Error(`history read failed: ${histErr.message}`);
    const previousBest = history?.[0]?.daily_steps as number | undefined;
    if (previousBest !== undefined && mySteps > previousBest) {
      const key = `record:${competitionDate}`;
      if (!(await hasNotification(supabaseAdmin, userId, "personal_record", key))) {
        await notify(
          supabaseAdmin,
          userId,
          "personal_record",
          "¡Nuevo récord personal!",
          `📈 ¡Superaste tu marca: ${mySteps.toLocaleString("es-CL")} pasos!`,
          { key, steps: mySteps, competition_date: competitionDate },
        );
        emitted.push("personal_record");
      }
    }
  }

  return Response.json({ date: competitionDate, emitted });
}
