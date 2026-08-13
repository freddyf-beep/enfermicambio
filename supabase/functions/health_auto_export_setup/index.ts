import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const SOURCE = "health_auto_export";
const TOKEN_BYTES = 32;

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

function bearerToken(req: Request): string | null {
  const value = (req.headers.get("authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
  return value.length >= 16 && value.length <= 4096 ? value : null;
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

function base64Url(bytes: Uint8Array): string {
  const binary = String.fromCharCode(...bytes);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function automationLink(
  endpoint: string,
  token: string,
  kind: "metrics" | "workouts",
): string {
  const params = new URLSearchParams({
    url: endpoint,
    name: kind === "metrics"
      ? "EnfermiCambio - Salud"
      : "EnfermiCambio - Entrenamientos",
    format: "json",
    enabled: "true",
    exportversion: "v2",
    // Export the complete previous and current day on every run. The bridge
    // upserts a daily aggregate, so an incremental lastsync window could
    // otherwise replace a complete total with only the latest slice.
    period: "none",
    // Five minutes matches the cadence used by the working manual setup. iOS
    // may defer background work, but the automation should keep trying often.
    syncinterval: "minutes",
    syncquantity: "5",
    headers: `Authorization,Bearer ${token}`,
    requesttimeout: "60",
    batchrequests: "true",
    notifyonupdate: "true",
    notifywhenrun: "false",
  });

  if (kind === "metrics") {
    params.set("datatype", "healthMetrics");
    params.set("metrics", [
      "Step Count",
      "Active Energy",
      "Walking + Running Distance",
      "Apple Exercise Time",
    ].join(","));
    params.set("aggregatedata", "true");
    params.set("interval", "hours");
  } else {
    params.set("datatype", "workouts");
    params.set("includeroutes", "true");
    params.set("includeworkoutmetadata", "true");
    params.set("workoutsmetadatainterval", "minutes");
  }

  // URLSearchParams serializes spaces as `+`. Health Auto Export documents
  // percent-encoded spaces (`%20`) in deep links, so normalize them here.
  // Literal plus signs (for example in "Walking + Running Distance") are
  // already encoded as `%2B` and remain unchanged.
  return `com.HealthExport://automation?${params.toString().replaceAll("+", "%20")}`;
}

export default {
  fetch: withSupabase(
    { auth: "none" },
    async (req, ctx) => {
      if (req.method === "OPTIONS") return jsonResponse({}, 204);
      if (req.method !== "POST") {
        return jsonResponse({ error: "Use POST" }, 405);
      }

      try {
        const jwt = bearerToken(req);
        if (!jwt) return jsonResponse({ error: "unauthenticated" }, 401);

        const { data: authData, error: authError } = await ctx.supabaseAdmin.auth
          .getUser(jwt);
        const userId = authData.user?.id;
        if (authError || !userId) {
          return jsonResponse({ error: "unauthenticated" }, 401);
        }

        const { data: profile, error: profileError } = await ctx.supabaseAdmin
          .from("profiles")
          .select("id")
          .eq("id", userId)
          .maybeSingle();
        if (profileError) {
          throw new Error(`profile lookup failed: ${profileError.message}`);
        }
        if (!profile) return jsonResponse({ error: "forbidden" }, 403);

        let body: Record<string, unknown> = {};
        try {
          body = await req.json() as Record<string, unknown>;
        } catch {
          // Empty payload keeps the historical setup/rotation behaviour.
        }

        if (body.action === "status") {
          const { data: existingToken, error: tokenError } = await ctx
            .supabaseAdmin
            .from("health_ingestion_tokens")
            .select("token_prefix, active, last_used_at")
            .eq("user_id", userId)
            .eq("source", SOURCE)
            .maybeSingle();
          if (tokenError) {
            throw new Error(`token status failed: ${tokenError.message}`);
          }

          const { data: latestActivity, error: activityError } = await ctx
            .supabaseAdmin
            .from("daily_activity")
            .select("activity_date, daily_steps, synced_at")
            .eq("user_id", userId)
            .eq("source_app", "Health Auto Export")
            .order("activity_date", { ascending: false })
            .limit(1)
            .maybeSingle();
          if (activityError) {
            throw new Error(`activity status failed: ${activityError.message}`);
          }

          const { data: latestRun, error: runError } = await ctx
            .supabaseAdmin
            .from("health_ingestion_runs")
            .select(
              "status, received_at, stage, metric_samples, manual_samples_skipped, workouts, route_points, imported_dates, warnings, error_message",
            )
            .eq("user_id", userId)
            .eq("source", SOURCE)
            .order("received_at", { ascending: false })
            .limit(1)
            .maybeSingle();
          if (runError) {
            throw new Error(`ingestion status failed: ${runError.message}`);
          }

          return jsonResponse({
            configured: Boolean(existingToken?.active),
            token_prefix: existingToken?.token_prefix ?? null,
            last_received_at: existingToken?.last_used_at ?? null,
            latest_activity_date: latestActivity?.activity_date ?? null,
            latest_daily_steps: latestActivity?.daily_steps ?? null,
            latest_synced_at: latestActivity?.synced_at ?? null,
            automations_expected: 2,
            last_run_status: latestRun?.status ?? null,
            last_run_received_at: latestRun?.received_at ?? null,
            last_run_stage: latestRun?.stage ?? null,
            last_run_metric_samples: latestRun?.metric_samples ?? 0,
            last_run_manual_samples_skipped: latestRun?.manual_samples_skipped ?? 0,
            last_run_workouts: latestRun?.workouts ?? 0,
            last_run_route_points: latestRun?.route_points ?? 0,
            last_run_imported_dates: latestRun?.imported_dates ?? [],
            last_run_warnings: latestRun?.warnings ?? [],
            last_run_error: latestRun?.error_message ?? null,
          });
        }

        const rawToken = base64Url(crypto.getRandomValues(
          new Uint8Array(TOKEN_BYTES),
        ));
        const tokenHash = await sha256Hex(rawToken);
        const tokenPrefix = rawToken.slice(0, 12);
        const { error: upsertError } = await ctx.supabaseAdmin
          .from("health_ingestion_tokens")
          .upsert({
            user_id: userId,
            token_hash: tokenHash,
            token_prefix: tokenPrefix,
            source: SOURCE,
            active: true,
            revoked_at: null,
            last_used_at: null,
          }, { onConflict: "user_id,source" });
        if (upsertError) {
          throw new Error(`token rotation failed: ${upsertError.message}`);
        }

        const endpoint = `${Deno.env.get("SUPABASE_URL")}/functions/v1/health_auto_export`;
        return jsonResponse({
          token_prefix: tokenPrefix,
          metrics_link: automationLink(endpoint, rawToken, "metrics"),
          workouts_link: automationLink(endpoint, rawToken, "workouts"),
        });
      } catch (error) {
        return jsonResponse({
          error: error instanceof Error ? error.message : String(error),
        }, 500);
      }
    },
  ),
};
