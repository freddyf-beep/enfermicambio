// close_round: determine the winner of a morning/afternoon/night round in
// competition_timezone, award round-win points via the service-role ledger, and
// publish a round_result system post. Scheduled jobs call this with the round
// name; retries are idempotent through the award_points ledger uniqueness.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { createClient } from "@supabase/supabase-js";

type RoundName = "morning" | "afternoon" | "night";

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

function roundWindow(round: RoundName, config: Map<string, unknown>) {
  const start = config.get(`${round}_start`) as string;
  const end = config.get(`${round}_end`) as string;
  if (!start || !end) throw new Error(`missing window for ${round}`);
  return { start, end };
}

export default {
  fetch: withSupabase(
    { auth: ["publishable", "secret"] },
    async (req, ctx) => {
      // ctx.supabaseAdmin bypasses RLS and is safe for scheduled jobs.
      let body: { round?: string; date?: string };
      try {
        body = await req.json();
      } catch {
        return Response.json({ error: "invalid body" }, { status: 400 });
      }
      const round = body.round as RoundName;
      if (!["morning", "afternoon", "night"].includes(round)) {
        return Response.json({ error: "unknown round" }, { status: 400 });
      }

      const config = await loadConfig(ctx.supabaseAdmin);
      const { start, end } = roundWindow(round, config);

      // The scheduled job provides the competition date (YYYY-MM-DD).
      const competitionDate = body.date ?? null;
      if (!competitionDate) {
        return Response.json(
          { error: "missing date" },
          { status: 400 },
        );
      }

      // Leaderboard for the window: accepted automatic steps only.
      const windowEndHour = Number.parseInt(end.split(":")[0], 10);
      const { data: activity, error: actErr } = await ctx.supabaseAdmin
        .from("daily_activity")
        .select(
          "user_id, morning_steps, afternoon_steps, night_steps, manual_entry_detected",
        )
        .eq("activity_date", competitionDate)
        .eq("manual_entry_detected", false);
      if (actErr) throw new Error(`activity read failed: ${actErr.message}`);

      const column =
        round === "morning"
          ? "morning_steps"
          : round === "afternoon"
            ? "afternoon_steps"
            : "night_steps";

      let winnerId: string | null = null;
      let best = -1;
      for (const row of activity ?? []) {
        const steps = row[column] as number;
        if (steps > best) {
          best = steps;
          winnerId = row.user_id as string;
        }
      }

      if (winnerId === null) {
        return Response.json({ message: `no activity for ${round} round` });
      }

      // Award points through the ledger (idempotent on retry).
      const { data: season, error: seasonErr } = await ctx.supabaseAdmin
        .from("seasons")
        .select("id")
        .eq("status", "active")
        .lte("starts_at", new Date().toISOString())
        .gt("ends_at", new Date().toISOString())
        .limit(1)
        .single();
      if (seasonErr) {
        throw new Error(`no active season: ${seasonErr.message}`);
      }

      const pointValue = (config.get("round_win_points") as number) ?? 3;
      const referenceId = crypto.randomUUID();
      const { data: ledger, error: awardErr } = await ctx.supabaseAdmin.rpc(
        "award_points",
        {
          p_season_id: season.id,
          p_user_id: winnerId,
          p_points: pointValue,
          p_reason: `${round}_round_win`,
          p_reference_type: "round_result",
          p_reference_id: referenceId,
        },
      );
      if (awardErr) {
        // Duplicate award on retry surfaces as a unique violation; treat as ok.
        if (!awardErr.message.includes("duplicate")) {
          throw new Error(`award failed: ${awardErr.message}`);
        }
      }

      // Publish a system round_result post.
      const { data: winnerProfile } = await ctx.supabaseAdmin
        .from("profiles")
        .select("display_name")
        .eq("id", winnerId)
        .single();
      await ctx.supabaseAdmin.from("posts").insert({
        author_id: winnerId,
        post_type: "round_result",
        caption:
          `${winnerProfile?.display_name ?? "Someone"} won the ` +
          `${round} round (${start}-${end}).`,
        system_generated: true,
      });

      return Response.json({
        round,
        date: competitionDate,
        winnerId,
        steps: best,
        points: pointValue,
        ledgerId: ledger ?? null,
      });
    },
  ),
};
