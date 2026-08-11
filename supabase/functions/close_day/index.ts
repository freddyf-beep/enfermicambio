// close_day: after the night round, award daily rank points (10/7/4/2),
// evaluate step-goal streaks, and publish the daily result post. Called by a
// scheduled job once per day; retries are idempotent through the ledger.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { createClient } from "@supabase/supabase-js";

async function loadConfig(supabaseAdmin: ReturnType<typeof createClient>) {
  const { data, error } = await supabaseAdmin
    .from("app_config")
    .select("config_key, config_value");
  if (error) throw new Error(`config read failed: ${error.message}`);
  const map = new Map<string, unknown>();
  for (const row of data ?? []) {
    map.set(row.config_key, row.config_value);
  }
  return map;
}

// Deterministic UUIDv5-style so ledger references are idempotent on retry.
const NAMESPACE_UUID = new Uint8Array([
  0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1,
  0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8,
]);

async function deterministicUuid(name: string): Promise<string> {
  const nameBytes = new TextEncoder().encode(name);
  const combined = new Uint8Array(NAMESPACE_UUID.length + nameBytes.length);
  combined.set(NAMESPACE_UUID, 0);
  combined.set(nameBytes, NAMESPACE_UUID.length);
  const digest = await crypto.subtle.digest("SHA-1", combined);
  const full = new Uint8Array(digest);
  const bytes = full.slice(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export default {
  fetch: withSupabase(
    { auth: ["publishable", "secret"] },
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
  let body: { date?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "invalid body" }, { status: 400 });
  }
  const competitionDate = body.date ?? null;
  if (!competitionDate) {
    return Response.json({ error: "missing date" }, { status: 400 });
  }

  const config = await loadConfig(supabaseAdmin);
  const rankPoints = (config.get("daily_rank_points") as Record<string, number>) ??
    { "1": 10, "2": 7, "3": 4, "4": 2 };
  const stepGoalDefault = (config.get("step_goal_default") as number) ?? 10000;

  const { data: season, error: seasonErr } = await supabaseAdmin
    .from("seasons")
    .select("id")
    .eq("status", "active")
    .lte("starts_at", new Date().toISOString())
    .gt("ends_at", new Date().toISOString())
    .limit(1)
    .single();
  if (seasonErr) throw new Error(`no active season: ${seasonErr.message}`);

  const { data: activity, error: actErr } = await supabaseAdmin
    .from("daily_activity")
    .select("user_id, daily_steps, manual_entry_detected")
    .eq("activity_date", competitionDate)
    .eq("manual_entry_detected", false);
  if (actErr) throw new Error(`activity read failed: ${actErr.message}`);

  const rows = (activity ?? []).sort((a, b) => b.daily_steps - a.daily_steps);

  const awarded: Record<string, number> = {};
  for (let i = 0; i < rows.length; i++) {
    const rank = i + 1;
    const points = rankPoints[String(rank)] ?? 0;
    const referenceId = await deterministicUuid(`daily_rank:${competitionDate}:${rows[i].user_id}`);
    const { error: awardErr } = await supabaseAdmin.rpc("award_points", {
      p_season_id: season.id,
      p_user_id: rows[i].user_id,
      p_points: points,
      p_reason: "daily_rank",
      p_reference_type: "daily_result",
      p_reference_id: referenceId,
    });
    if (awardErr && !awardErr.message.includes("duplicate")) {
      throw new Error(`rank award failed: ${awardErr.message}`);
    }
    awarded[rows[i].user_id] = points;
  }

  // Step-goal streaks: award the step goal bonus and update streaks.
  const streakPoints = (config.get("step_goal_points") as number) ?? 2;
  const { data: profiles } = await supabaseAdmin
    .from("profiles")
    .select("id, daily_step_target");

  for (const row of rows) {
    const profile = (profiles ?? []).find((p) => p.id === row.user_id);
    const target = profile?.daily_step_target ?? stepGoalDefault;
    if (row.daily_steps < target) continue;

    const refId = await deterministicUuid(`step_goal:${competitionDate}:${row.user_id}`);
    const { error: goalErr } = await supabaseAdmin.rpc("award_points", {
      p_season_id: season.id,
      p_user_id: row.user_id,
      p_points: streakPoints,
      p_reason: "step_goal",
      p_reference_type: "daily_result",
      p_reference_id: refId,
    });
    if (goalErr && !goalErr.message.includes("duplicate")) {
      throw new Error(`step goal award failed: ${goalErr.message}`);
    }

    // Update the step_goal streak row.
    const { data: streak } = await supabaseAdmin
      .from("streaks")
      .select("id, current_count, longest_count, last_qualified_date")
      .eq("user_id", row.user_id)
      .eq("streak_type", "step_goal")
      .maybeSingle();
    const current = streak?.current_count ?? 0;
    const longest = streak?.longest_count ?? 0;
    const lastDate = streak?.last_qualified_date
      ? new Date(streak.last_qualified_date)
      : null;
    const day = new Date(`${competitionDate}T00:00:00Z`);
    const isConsecutive = lastDate
      ? (day.getTime() - lastDate.getTime()) / 86400000 === 1
      : false;
    const nextCount = isConsecutive ? current + 1 : 1;
    const nextLongest = Math.max(longest, nextCount);

    await supabaseAdmin.from("streaks").upsert({
      user_id: row.user_id,
      streak_type: "step_goal",
      current_count: nextCount,
      longest_count: nextLongest,
      last_qualified_date: competitionDate,
    }, { onConflict: "user_id,streak_type" });
  }

  // Publish the daily result post.
  const winnerId = rows.length > 0 ? rows[0].user_id : null;
  let winnerName = "No one";
  if (winnerId) {
    const { data: winner } = await supabaseAdmin
      .from("profiles")
      .select("display_name")
      .eq("id", winnerId)
      .single();
    winnerName = winner?.display_name ?? "Someone";
  }
  const dayLabel = competitionDate;
  await supabaseAdmin.from("posts").insert({
    author_id: winnerId ?? profiles?.[0]?.id,
    post_type: "round_result",
    caption:
      `Daily result for ${dayLabel}: ${winnerName} takes the day` +
      (rows.length > 0 ? ` with ${rows[0].daily_steps} steps.` : "."),
    system_generated: true,
  });

  return Response.json({ date: competitionDate, awarded });
}
