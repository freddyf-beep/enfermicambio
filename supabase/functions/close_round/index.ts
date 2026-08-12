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

// Deterministic UUIDv5-style from a namespace + name so ledger references are
// idempotent across scheduled-job retries.
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

  const config = await loadConfig(supabaseAdmin);
  const { start, end } = roundWindow(round, config);

  const competitionDate = body.date ?? null;
  if (!competitionDate) {
    return Response.json({ error: "missing date" }, { status: 400 });
  }

  const { data: activity, error: actErr } = await supabaseAdmin
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

  const { data: season, error: seasonErr } = await supabaseAdmin
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
  // Deterministic reference id so job retries are idempotent: the ledger
  // unique constraint rejects a duplicate award on retry.
  const referenceId = await deterministicUuid(`${round}:${competitionDate}`);
  const { error: awardErr } = await supabaseAdmin.rpc("award_points", {
    p_season_id: season.id,
    p_user_id: winnerId,
    p_points: pointValue,
    p_reason: `${round}_round_win`,
    p_reference_type: "round_result",
    p_reference_id: referenceId,
  });
  if (awardErr && !awardErr.message.includes("duplicate")) {
    throw new Error(`award failed: ${awardErr.message}`);
  }

  const { data: winnerProfile } = await supabaseAdmin
    .from("profiles")
    .select("display_name")
    .eq("id", winnerId)
    .single();
  await supabaseAdmin.from("posts").insert({
    author_id: winnerId,
    post_type: "round_result",
    caption:
      `${winnerProfile?.display_name ?? "Someone"} won the ` +
      `${round} round (${start}-${end}).`,
    system_generated: true,
  });

  // Notify all four users about the round result (idempotent per key).
  const roundLabel =
    round === "morning" ? "la mañana" : round === "afternoon" ? "la tarde" : "la noche";
  const winnerName = winnerProfile?.display_name ?? "Alguien";
  const notifKey = `round_result:${round}:${competitionDate}`;
  const { data: allProfiles } = await supabaseAdmin
    .from("profiles")
    .select("id");
  for (const p of allProfiles ?? []) {
    const { data: dup } = await supabaseAdmin
      .from("notifications")
      .select("id")
      .eq("user_id", p.id)
      .eq("type", "round_result")
      .eq("payload->>key", notifKey)
      .limit(1);
    if ((dup?.length ?? 0) > 0) continue;
    const { error: notifErr } = await supabaseAdmin.rpc("insert_notification", {
      p_user_id: p.id,
      p_type: "round_result",
      p_title: `${winnerName} ganó la ronda`,
      p_body: `🏆 ${winnerName} ganó la ronda de ${roundLabel} con ${best.toLocaleString("es-CL")} pasos.`,
      p_payload: {
        key: notifKey,
        round,
        competition_date: competitionDate,
        winner_id: winnerId,
      },
    });
    if (notifErr) throw new Error(`round notify failed: ${notifErr.message}`);
  }

  return Response.json({
    round,
    date: competitionDate,
    winnerId,
    steps: best,
    points: pointValue,
    referenceId,
  });
}
