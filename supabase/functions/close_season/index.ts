// close_season: freeze standings, write season_results for all users, crown
// the champion (award + publish), and create the next season. Idempotent:
// season_results PK (season_id, user_id) and a status guard prevent double
// closure. Called by a scheduled job at season end.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { createClient } from "@supabase/supabase-js";

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
  _req: Request,
): Promise<Response> {
  // Find a season that has ended but is not yet closed.
  const { data: season, error: seasonErr } = await supabaseAdmin
    .from("seasons")
    .select("id, name, starts_at, ends_at, status")
    .eq("status", "active")
    .lte("ends_at", new Date().toISOString())
    .limit(1)
    .single();
  if (seasonErr) {
    if (seasonErr.code === "PGRST116") {
      return Response.json({ message: "no season to close" });
    }
    throw new Error(`season read failed: ${seasonErr.message}`);
  }

  // Freeze standings from the ledger sum.
  const { data: standings, error: stErr } = await supabaseAdmin
    .from("season_standings")
    .select("user_id, display_name, total_points, position")
    .eq("season_id", season.id)
    .order("position");
  if (stErr) throw new Error(`standings read failed: ${stErr.message}`);

  // Write season_results (idempotent on retry via PK).
  for (const row of standings ?? []) {
    const { error: resErr } = await supabaseAdmin.from("season_results").upsert(
      {
        season_id: season.id,
        user_id: row.user_id,
        final_points: Math.round(row.total_points),
        final_rank: row.position,
      },
      { onConflict: "season_id,user_id" },
    );
    if (resErr) throw new Error(`results write failed: ${resErr.message}`);
  }

  // Mark the season closed (guarded; a retry sees it already closed).
  const { error: closeErr } = await supabaseAdmin
    .from("seasons")
    .update({ status: "closed" })
    .eq("id", season.id)
    .eq("status", "active");
  if (closeErr) throw new Error(`season close failed: ${closeErr.message}`);

  // Crown the champion if standings exist.
  const champion = standings?.[0];
  if (champion) {
    const { error: champErr } = await supabaseAdmin.from("posts").insert({
      author_id: champion.user_id,
      post_type: "season",
      caption:
        `Season champion: ${champion.display_name} with ` +
        `${Math.round(champion.total_points)} points.`,
      system_generated: true,
    });
    if (champErr) throw new Error(`champion post failed: ${champErr.message}`);
  }

  // Create the next season.
  const durationMs =
    new Date(season.ends_at).getTime() - new Date(season.starts_at).getTime();
  const nextStart = new Date(new Date(season.ends_at).getTime() + 1000);
  const nextEnd = new Date(nextStart.getTime() + durationMs);
  const nextNumber = parseInt(season.name.replace(/\D+/g, "") || "0", 10) + 1;

  const { error: nextErr } = await supabaseAdmin.from("seasons").insert({
    name: `Season ${nextNumber}`,
    starts_at: nextStart.toISOString(),
    ends_at: nextEnd.toISOString(),
    status: "pending",
  });
  if (nextErr) throw new Error(`next season create failed: ${nextErr.message}`);

  return Response.json({
    seasonId: season.id,
    closed: true,
    champion: champion?.display_name ?? null,
    nextSeason: `Season ${nextNumber}`,
  });
}
