import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { withSupabase } from "@supabase/server";

const SOURCE = "health_auto_export";
const DEFAULT_TIME_ZONE = "America/Santiago";
const MAX_BODY_BYTES = 25 * 1024 * 1024;
const INSERT_CHUNK_SIZE = 500;

type JsonObject = Record<string, unknown>;
type AdminClient = ReturnType<typeof createClient>;
type MetricKind = "steps" | "calories" | "distance" | "exercise";

type DailyAccumulator = {
  morningSteps: number;
  afternoonSteps: number;
  nightSteps: number;
  dailySteps: number;
  activeCalories: number;
  distanceMeters: number;
  exerciseMinutes: number;
  manualEntryDetected: boolean;
  sampleCount: number;
  device?: string;
  metricNames: Set<string>;
};

type ImportSummary = {
  dates: string[];
  metricSamples: number;
  manualSamplesSkipped: number;
  workouts: number;
  routePoints: number;
  warnings: string[];
};

const METRIC_KINDS = new Map<string, MetricKind>([
  ["step_count", "steps"],
  ["steps", "steps"],
  ["stepcount", "steps"],
  ["active_energy", "calories"],
  ["active_energy_burned", "calories"],
  ["activeenergyburned", "calories"],
  ["active_calories", "calories"],
  ["walking_running_distance", "distance"],
  ["walking_+_running_distance", "distance"],
  ["walking_&_running_distance", "distance"],
  ["distance_walking_running", "distance"],
  ["distance_walking_+_running", "distance"],
  ["walkingrunningdistance", "distance"],
  ["apple_exercise_time", "exercise"],
  ["exercise_time", "exercise"],
  ["exercise_minutes", "exercise"],
  ["appleexercisetime", "exercise"],
]);

function jsonResponse(
  body: JsonObject,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-health-export-token, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

function bearerToken(req: Request): string | null {
  const authorization = req.headers.get("authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  const value = match?.[1]?.trim() ||
    req.headers.get("x-health-export-token")?.trim() || "";
  if (value.length < 32 || value.length > 256) return null;
  return value;
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

function asObject(value: unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;
}

function asString(value: unknown): string | null {
  if (typeof value === "string" && value.trim()) return value.trim();
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  return null;
}

function asNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value.replace(",", "."));
    return Number.isFinite(parsed) ? parsed : null;
  }
  const object = asObject(value);
  if (object) {
    for (const key of ["qty", "value", "quantity", "amount"]) {
      const nested = asNumber(object[key]);
      if (nested !== null) return nested;
    }
  }
  return null;
}

function normaliseName(value: unknown): string {
  return (asString(value) ?? "")
    .trim()
    .toLowerCase()
    .replace(/[.\s-]+/g, "_");
}

function parseHealthDate(value: unknown): Date | null {
  const text = asString(value);
  if (!text) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    return new Date(`${text}T12:00:00.000Z`);
  }

  // Health Auto Export commonly uses: 2024-02-06 14:30:00 -0800.
  const match = text.match(
    /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2}(?:\.\d+)?)[ ]?([+-])(\d{2}):?(\d{2})$/,
  );
  if (match) {
    const parsed = new Date(
      `${match[1]}T${match[2]}${match[3]}${match[4]}:${match[5]}`,
    );
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  const parsed = new Date(text.replace(" ", "T"));
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function durationSeconds(value: unknown): number | null {
  const numeric = asNumber(value);
  if (numeric !== null && numeric > 0) return numeric;
  const text = asString(value);
  if (!text) return null;
  const iso = text.match(/^PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?$/i);
  if (!iso) return null;
  return Number(iso[1] ?? 0) * 3600 + Number(iso[2] ?? 0) * 60 +
    Number(iso[3] ?? 0);
}

function unitsOf(sample: JsonObject, metric: JsonObject): string {
  return normaliseName(sample.units ?? sample.unit ?? metric.units ?? metric.unit);
}

function convertMetricValue(
  kind: MetricKind,
  value: number,
  units: string,
): number {
  if (kind === "distance") {
    if (units.includes("km")) return value * 1000;
    if (units.includes("mile") || units === "mi") return value * 1609.344;
    if (units.includes("ft") || units.includes("foot")) return value * 0.3048;
    return value;
  }
  if (kind === "exercise") {
    if (units.includes("sec")) return value / 60;
    if (units.includes("hour") || units === "hr" || units === "h") return value * 60;
    return value;
  }
  if (kind === "calories") {
    if (units.includes("kj")) return value * 0.239005736;
    if (units === "cal" || units === "calorie") return value / 1000;
    return value;
  }
  return value;
}

function zonedParts(
  date: Date,
  timeZone: string,
): { date: string; hour: number } {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      hourCycle: "h23",
    }).formatToParts(date);
    const values = new Map(parts.map((part) => [part.type, part.value]));
    return {
      date: `${values.get("year")}-${values.get("month")}-${values.get("day")}`,
      hour: Number(values.get("hour") ?? 0),
    };
  } catch {
    const iso = date.toISOString();
    return { date: iso.slice(0, 10), hour: date.getUTCHours() };
  }
}

function isManualRecord(metric: JsonObject, sample: JsonObject): boolean {
  for (const object of [sample, metric]) {
    for (const key of ["isManual", "manual", "wasUserEntered", "userEntered"]) {
      if (object[key] === true) return true;
    }
  }
  const sourceText = [
    sample.source,
    sample.dataSource,
    sample.recordingMethod,
    sample.recording_method,
    metric.source,
    metric.dataSource,
  ].filter(Boolean).map(String).join(" ").toLowerCase();
  return /manual|user[ _-]?entered/.test(sourceText);
}

function newDailyAccumulator(): DailyAccumulator {
  return {
    morningSteps: 0,
    afternoonSteps: 0,
    nightSteps: 0,
    dailySteps: 0,
    activeCalories: 0,
    distanceMeters: 0,
    exerciseMinutes: 0,
    manualEntryDetected: false,
    sampleCount: 0,
    metricNames: new Set<string>(),
  };
}

function addMetricSample(
  rows: Map<string, DailyAccumulator>,
  date: string,
  hour: number,
  kind: MetricKind,
  value: number,
  metricName: string,
  device?: string,
): void {
  const row = rows.get(date) ?? newDailyAccumulator();
  row.sampleCount++;
  row.metricNames.add(metricName);
  if (device && !row.device) row.device = device.slice(0, 120);
  switch (kind) {
    case "steps":
      row.dailySteps += value;
      if (hour >= 6 && hour < 12) row.morningSteps += value;
      else if (hour >= 12 && hour < 18) row.afternoonSteps += value;
      else row.nightSteps += value;
      break;
    case "calories":
      row.activeCalories += value;
      break;
    case "distance":
      row.distanceMeters += value;
      break;
    case "exercise":
      row.exerciseMinutes += value;
      break;
  }
  rows.set(date, row);
}

function metricSamples(payload: JsonObject): JsonObject[] {
  const metrics = Array.isArray(payload.metrics)
    ? payload.metrics
    : Array.isArray(asObject(payload.data)?.metrics)
    ? asObject(payload.data)?.metrics
    : [];
  return metrics.map(asObject).filter((value): value is JsonObject => value !== null);
}

function workoutSamples(payload: JsonObject): JsonObject[] {
  const workouts = Array.isArray(payload.workouts)
    ? payload.workouts
    : Array.isArray(asObject(payload.data)?.workouts)
    ? asObject(payload.data)?.workouts
    : [];
  return workouts.map(asObject).filter((value): value is JsonObject => value !== null);
}

function quantityObject(value: unknown): JsonObject {
  return asObject(value) ?? {};
}

function workoutQuantity(value: unknown): { value: number | null; units: string } {
  const object = quantityObject(value);
  return {
    value: asNumber(object.qty ?? object.value ?? value),
    units: normaliseName(object.units ?? object.unit),
  };
}

function distanceMeters(value: unknown): number | null {
  const quantity = workoutQuantity(value);
  if (quantity.value === null) return null;
  return convertMetricValue("distance", quantity.value, quantity.units);
}

function calories(value: unknown): number | null {
  const quantity = workoutQuantity(value);
  if (quantity.value === null) return null;
  return convertMetricValue("calories", quantity.value, quantity.units);
}

function speedMetersPerSecond(value: unknown): number | null {
  const quantity = workoutQuantity(value);
  if (quantity.value === null) return null;
  if (quantity.units.includes("km")) return quantity.value / 3.6;
  if (quantity.units.includes("mile") || quantity.units === "mph") {
    return quantity.value * 0.44704;
  }
  return quantity.value;
}

async function stableWorkoutId(workout: JsonObject, startedAt: Date): Promise<string> {
  const name = asString(workout.name ?? workout.workoutType ?? workout.type) ?? "workout";
  const ended = asString(workout.end ?? workout.endDate ?? workout.endedAt) ?? "";
  return `hae:${await sha256Hex(`${name}|${startedAt.toISOString()}|${ended}`)}`;
}

function routePoints(
  workout: JsonObject,
  startedAt: Date,
): JsonObject[] {
  if (!Array.isArray(workout.route)) return [];
  const points: JsonObject[] = [];
  for (const value of workout.route) {
    const point = asObject(value);
    if (!point) continue;
    const latitude = asNumber(point.latitude ?? point.lat);
    const longitude = asNumber(point.longitude ?? point.lon ?? point.lng);
    if (latitude === null || longitude === null) continue;
    const timestamp = parseHealthDate(point.timestamp ?? point.date) ?? startedAt;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue;
    points.push({
      timestamp: timestamp.toISOString(),
      latitude,
      longitude,
      altitude: asNumber(point.altitude),
      accuracy: asNumber(point.horizontalAccuracy ?? point.accuracy),
      bearing: asNumber(point.course ?? point.bearing),
    });
  }
  return points;
}

async function insertRoutePoints(
  admin: AdminClient,
  workoutId: string,
  points: JsonObject[],
): Promise<void> {
  if (points.length === 0) return;
  for (let index = 0; index < points.length; index += INSERT_CHUNK_SIZE) {
    const chunk = points.slice(index, index + INSERT_CHUNK_SIZE).map((point) => ({
      workout_id: workoutId,
      ...point,
    }));
    const { error } = await admin.from("workout_route_points").insert(chunk);
    if (error) throw new Error(`route point insert failed: ${error.message}`);
  }
}

async function importMetrics(
  admin: AdminClient,
  userId: string,
  payload: JsonObject,
  timeZone: string,
  importedAt: string,
): Promise<{ rows: string[]; samples: number; skippedManual: number }> {
  const daily = new Map<string, DailyAccumulator>();
  let samples = 0;
  let skippedManual = 0;

  for (const metric of metricSamples(payload)) {
    const metricName = normaliseName(metric.name ?? metric.type);
    const kind = METRIC_KINDS.get(metricName);
    if (!kind) continue;
    const data = Array.isArray(metric.data) ? metric.data : [];
    for (const value of data) {
      const sample = asObject(value);
      if (!sample) continue;
      const rawValue = asNumber(sample.qty ?? sample.value ?? sample.quantity ?? sample.amount);
      const start = parseHealthDate(
        sample.startDate ?? sample.start_date ?? sample.date ?? sample.timestamp ??
          sample.endDate,
      );
      if (rawValue === null || start === null) continue;
      samples++;
      if (isManualRecord(metric, sample)) {
        skippedManual++;
        const date = zonedParts(start, timeZone).date;
        const row = daily.get(date) ?? newDailyAccumulator();
        row.manualEntryDetected = true;
        daily.set(date, row);
        continue;
      }
      const local = zonedParts(start, timeZone);
      addMetricSample(
        daily,
        local.date,
        local.hour,
        kind,
        Math.max(0, convertMetricValue(kind, rawValue, unitsOf(sample, metric))),
        metricName,
        asString(sample.source ?? sample.dataSource ?? metric.source) ?? undefined,
      );
    }
  }

  const rows = [...daily.entries()];
  if (rows.length === 0) return { rows: [], samples, skippedManual };
  const upserts = rows.map(([date, row]) => ({
    user_id: userId,
    activity_date: date,
    morning_steps: Math.max(0, Math.round(row.morningSteps)),
    afternoon_steps: Math.max(0, Math.round(row.afternoonSteps)),
    night_steps: Math.max(0, Math.round(row.nightSteps)),
    daily_steps: Math.max(0, Math.round(row.dailySteps)),
    active_calories: Number(row.activeCalories.toFixed(2)),
    distance_meters: Number(row.distanceMeters.toFixed(2)),
    exercise_minutes: Number(row.exerciseMinutes.toFixed(2)),
    synced_at: importedAt,
    source_platform: "ios",
    source_app: "Health Auto Export",
    source_device: row.device ?? "Apple Health",
    recording_method: row.manualEntryDetected ? "mixed" : "automatic",
    // Manual samples are skipped from the totals, but the flag remains true
    // so rankings and season totals can exclude a mixed/contaminated day.
    manual_entry_detected: row.manualEntryDetected,
    source_metadata: {
      bridge: SOURCE,
      raw_payload_stored: false,
      imported_at: importedAt,
      metric_samples: row.sampleCount,
      metrics: [...row.metricNames].sort(),
      manual_samples_skipped: skippedManual,
      timezone: timeZone,
    },
  }));
  const { error } = await admin.from("daily_activity").upsert(upserts, {
    onConflict: "user_id,activity_date",
  });
  if (error) throw new Error(`daily activity upsert failed: ${error.message}`);
  return { rows: rows.map(([date]) => date), samples, skippedManual };
}

async function importWorkouts(
  admin: AdminClient,
  userId: string,
  payload: JsonObject,
): Promise<{ workouts: number; routePoints: number }> {
  let imported = 0;
  let routeCount = 0;
  let stage = "sample";
  try {
  for (const workout of workoutSamples(payload)) {
    const startedAt = parseHealthDate(
      workout.start ?? workout.startDate ?? workout.startedAt,
    );
    if (!startedAt) continue;
    const suppliedDuration = durationSeconds(workout.duration);
    const suppliedEnd = parseHealthDate(
      workout.end ?? workout.endDate ?? workout.endedAt,
    );
    const endedAt = suppliedEnd && suppliedEnd > startedAt
      ? suppliedEnd
      : new Date(startedAt.getTime() + Math.max(1, suppliedDuration ?? 1) * 1000);
    const duration = Math.max(
      1,
      Math.round(suppliedDuration ?? (endedAt.getTime() - startedAt.getTime()) / 1000),
    );
    const name = (asString(workout.name ?? workout.workoutType ?? workout.type) ?? "Entrenamiento")
      .slice(0, 120);
    const externalId = asString(workout.id) ?? await stableWorkoutId(workout, startedAt);
    const distance = distanceMeters(workout.distance);
    const activeCalories = calories(workout.activeEnergyBurned ?? workout.activeCalories);
    const avgSpeed = speedMetersPerSecond(workout.avgSpeed ?? workout.averageSpeed);
    const pace = distance && distance > 0 ? duration / (distance / 1000) : null;
    const points = routePoints(workout, startedAt);

    stage = "lookup";
    const { data: existing, error: existingError } = await admin
      .from("workouts")
      .select("id, route_available")
      .eq("source", SOURCE)
      .eq("external_id", externalId)
      .maybeSingle();
    if (existingError) throw new Error(`workout lookup failed: ${existingError.message}`);

    const workoutRow = {
      user_id: userId,
      external_id: externalId,
      source: SOURCE,
      workout_type: name,
      started_at: startedAt.toISOString(),
      ended_at: endedAt.toISOString(),
      duration_seconds: duration,
      distance_meters: distance,
      active_calories: activeCalories,
      avg_pace: pace,
      avg_speed: avgSpeed,
      route_available: points.length > 0 || Boolean(existing?.route_available),
    };
    let savedId: string;
    stage = "save";
    if (existing?.id) {
      const { data: saved, error: saveError } = await admin
        .from("workouts")
        .update(workoutRow)
        .eq("id", existing.id)
        .select("id")
        .single();
      if (saveError || !saved) {
        throw new Error(`workout update failed: ${saveError?.message ?? "missing id"}`);
      }
      savedId = saved.id as string;
    } else {
      const { data: saved, error: saveError } = await admin
        .from("workouts")
        .insert(workoutRow)
        .select("id")
        .single();
      if (saveError || !saved) {
        throw new Error(`workout insert failed: ${saveError?.message ?? "missing id"}`);
      }
      savedId = saved.id as string;
    }

    if (points.length > 0) {
      stage = "route_cleanup";
      const { error: deleteError } = await admin
        .from("workout_route_points")
        .delete()
        .eq("workout_id", savedId);
      if (deleteError) throw new Error(`route cleanup failed: ${deleteError.message}`);
      stage = "route_insert";
      await insertRoutePoints(admin, savedId, points);
      routeCount += points.length;
    }
    imported++;
  }
  return { workouts: imported, routePoints: routeCount };
  } catch (error) {
    console.error(
      `Health Auto Export workout import failed at ${stage}`,
      error instanceof Error ? error.message : String(error),
    );
    throw new Error(`workout_stage:${stage}`);
  }
}

async function refreshGamification(
  admin: AdminClient,
  userId: string,
  dates: string[],
  bridgeToken: string,
): Promise<string[]> {
  const warnings: string[] = [];
  for (const date of dates) {
    const { error: achievementError } = await admin.rpc("evaluate_achievements", {
      p_user_id: userId,
      p_date: date,
    });
    if (achievementError) warnings.push("achievements not refreshed");

    // The bridge token is also accepted by generate_events for this exact
    // per-user flow. This keeps step milestones, overtakes and leader-change
    // notifications in the same server-authoritative pipeline as the health
    // upsert, without exposing another client credential.
    const projectUrl = Deno.env.get("SUPABASE_URL");
    if (!projectUrl) {
      warnings.push("events not refreshed");
      continue;
    }
    try {
      const response = await fetch(
        `${projectUrl}/functions/v1/generate_events`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${bridgeToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ user_id: userId, date }),
        },
      );
      if (!response.ok) warnings.push("events not refreshed");
    } catch {
      warnings.push("events not refreshed");
    }
  }
  return [...new Set(warnings)];
}

async function handle(admin: AdminClient, req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return jsonResponse({ ok: true });
  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST for Health Auto Export data" }, 405);
  }

  const token = bearerToken(req);
  if (!token) return jsonResponse({ error: "unauthorized" }, 401);

  let stage = "token";
  try {
    const tokenHash = await sha256Hex(token);
  const { data: tokenRow, error: tokenError } = await admin
    .from("health_ingestion_tokens")
    .select("user_id")
    .eq("token_hash", tokenHash)
    .eq("active", true)
    .maybeSingle();
  if (tokenError) {
    console.error("Health bridge token lookup failed", tokenError.message);
    return jsonResponse({ error: "bridge unavailable" }, 503);
  }
  if (!tokenRow?.user_id) return jsonResponse({ error: "unauthorized" }, 401);

  stage = "payload";
  const byteLength = Number(req.headers.get("content-length") ?? 0);
  if (byteLength > MAX_BODY_BYTES) return jsonResponse({ error: "payload too large" }, 413);
  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return jsonResponse({ error: "payload too large" }, 413);
  }

  let payload: JsonObject;
  try {
    const parsed = JSON.parse(rawBody);
    payload = asObject(parsed) ?? {};
  } catch {
    return jsonResponse({ error: "invalid JSON" }, 400);
  }

  const userId = tokenRow.user_id as string;
  stage = "profile";
  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("id, timezone")
    .eq("id", userId)
    .maybeSingle();
  if (profileError || !profile) return jsonResponse({ error: "user unavailable" }, 403);

  const { data: config } = await admin
    .from("app_config")
    .select("config_value")
    .eq("config_key", "competition_timezone")
    .maybeSingle();
  const configuredTimeZone = asString(config?.config_value);
  const timeZone = configuredTimeZone ?? asString(profile.timezone) ?? DEFAULT_TIME_ZONE;
  const importedAt = new Date().toISOString();

  stage = "metrics";
  const metricResult = await importMetrics(admin, userId, payload, timeZone, importedAt);
  stage = "workouts";
  const workoutResult = await importWorkouts(admin, userId, payload);
  stage = "achievements";
  const warnings = await refreshGamification(
    admin,
    userId,
    metricResult.rows,
    token,
  );

  stage = "token_last_used";
  await admin
    .from("health_ingestion_tokens")
    .update({ last_used_at: importedAt })
    .eq("token_hash", tokenHash);

  const summary: ImportSummary = {
    dates: metricResult.rows,
    metricSamples: metricResult.samples,
    manualSamplesSkipped: metricResult.skippedManual,
    workouts: workoutResult.workouts,
    routePoints: workoutResult.routePoints,
    warnings,
  };
    return jsonResponse({ ok: true, imported: summary });
  } catch (error) {
    console.error(
      `Health Auto Export bridge failed at ${stage}`,
      error instanceof Error ? error.message : String(error),
    );
    return jsonResponse({ error: "bridge failed" }, 500);
  }
}

export default {
  fetch: withSupabase(
    { auth: "none" },
    async (req, ctx) => {
      try {
        return await handle(ctx.supabaseAdmin, req);
      } catch (error) {
        console.error(
          "Health Auto Export bridge failed",
          error instanceof Error ? error.message : String(error),
        );
        return jsonResponse({ error: "bridge failed" }, 500);
      }
    },
  ),
};
