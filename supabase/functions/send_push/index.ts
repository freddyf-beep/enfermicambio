import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { createClient } from "@supabase/supabase-js";
import { importPKCS8, SignJWT } from "npm:jose@6.0.10";
import webpush from "npm:web-push@3.6.7";

type AdminClient = ReturnType<typeof createClient>;
type OutboxRow = { id: string; notification_id: string; user_id: string };
type NotificationRow = {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  payload: Record<string, unknown> | null;
};
type NativePushDevice = {
  token: string;
  platform: "android" | "ios";
  provider: "fcm" | "apns";
  app_id: string;
};
type WebPushDevice = {
  endpoint: string;
  p256dh: string;
  auth: string;
  provider: "web";
};
type NtfyDevice = {
  topic: string;
  server_url: string;
  provider: "ntfy";
};
type PushDevice = NativePushDevice | WebPushDevice | NtfyDevice;
type DeliveryResult = { ok: boolean; permanent: boolean; error?: string };

let fcmAccessToken: { value: string; expiresAt: number } | null = null;

function env(name: string): string {
  return (Deno.env.get(name) ?? "").trim();
}

function privateKey(value: string): string {
  return value.replace(/\\n/g, "\n").trim();
}

function jsonObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function stringData(payload: Record<string, unknown> | null): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(payload ?? {})) {
    if (value == null) continue;
    result[key] = typeof value === "string" ? value : JSON.stringify(value);
  }
  return result;
}

async function dispatchKeyIsValid(
  supabaseAdmin: AdminClient,
  request: Request,
): Promise<boolean> {
  const supplied = request.headers.get("x-enfermicambio-dispatch-key") ?? "";
  if (supplied.length < 32) return false;
  const { data, error } = await supabaseAdmin
    .from("push_dispatch_secrets")
    .select("dispatch_key")
    .eq("id", true)
    .maybeSingle();
  if (error || !data?.dispatch_key) return false;
  return supplied === data.dispatch_key;
}

async function fcmServiceAccount(): Promise<{
  projectId: string;
  clientEmail: string;
  privateKey: string;
} | null> {
  const json = env("FCM_SERVICE_ACCOUNT_JSON");
  if (json) {
    try {
      const parsed = JSON.parse(json) as Record<string, unknown>;
      const projectId = String(parsed.project_id ?? "");
      const clientEmail = String(parsed.client_email ?? "");
      const key = privateKey(String(parsed.private_key ?? ""));
      if (projectId && clientEmail && key) {
        return { projectId, clientEmail, privateKey: key };
      }
    } catch (_) {
      // Fall through to the separate secrets below.
    }
  }

  const projectId = env("FCM_PROJECT_ID");
  const clientEmail = env("FCM_CLIENT_EMAIL");
  const key = privateKey(env("FCM_PRIVATE_KEY"));
  if (!projectId || !clientEmail || !key) return null;
  return { projectId, clientEmail, privateKey: key };
}

async function googleAccessToken(): Promise<{
  token: string;
  projectId: string;
} | null> {
  const account = await fcmServiceAccount();
  if (!account) return null;
  const now = Math.floor(Date.now() / 1000);
  if (fcmAccessToken && fcmAccessToken.expiresAt > now + 60) {
    return { token: fcmAccessToken.value, projectId: account.projectId };
  }

  const key = await importPKCS8(account.privateKey, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.clientEmail)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`FCM OAuth ${response.status}: ${await response.text()}`);
  }
  const data = await response.json() as { access_token?: string; expires_in?: number };
  if (!data.access_token) throw new Error("FCM OAuth returned no access token");
  fcmAccessToken = {
    value: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return { token: data.access_token, projectId: account.projectId };
}

async function sendFcm(
  device: PushDevice,
  notification: NotificationRow,
): Promise<DeliveryResult> {
  const auth = await googleAccessToken();
  if (!auth) {
    return { ok: false, permanent: false, error: "FCM no está configurado" };
  }

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(auth.projectId)}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${auth.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: { title: notification.title, body: notification.body },
          data: {
            notification_id: notification.id,
            type: notification.type,
            ...stringData(notification.payload),
          },
          android: {
            priority: "high",
            notification: { channel_id: "competencia", sound: "default" },
          },
        },
      }),
    },
  );
  if (response.ok) return { ok: true, permanent: false };
  const errorBody = await response.text();
  const permanent = /UNREGISTERED|INVALID_ARGUMENT|NOT_FOUND/i.test(errorBody);
  return {
    ok: false,
    permanent,
    error: `FCM ${response.status}: ${errorBody.slice(0, 500)}`,
  };
}

async function sendApns(
  device: PushDevice,
  notification: NotificationRow,
): Promise<DeliveryResult> {
  const keyId = env("APNS_KEY_ID");
  const teamId = env("APNS_TEAM_ID");
  const bundleId = env("APNS_BUNDLE_ID") || device.app_id;
  const p8 = privateKey(env("APNS_PRIVATE_KEY"));
  if (!keyId || !teamId || !bundleId || !p8) {
    return { ok: false, permanent: false, error: "APNs no está configurado" };
  }

  const key = await importPKCS8(p8, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId, typ: "JWT" })
    .setIssuer(teamId)
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);

  const host = env("APNS_USE_SANDBOX") === "true"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  const response = await fetch(`${host}/3/device/${device.token}`, {
    method: "POST",
    headers: {
      Authorization: `bearer ${token}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: { title: notification.title, body: notification.body },
        sound: "default",
        badge: 1,
      },
      notification_id: notification.id,
      type: notification.type,
      ...stringData(notification.payload),
    }),
  });
  if (response.ok) return { ok: true, permanent: false };
  const errorBody = await response.text();
  const permanent = /BadDeviceToken|DeviceTokenNotForTopic|Unregistered|ExpiredToken/i.test(errorBody) ||
    response.status === 410;
  return {
    ok: false,
    permanent,
    error: `APNs ${response.status}: ${errorBody.slice(0, 500)}`,
  };
}

function webPushConfiguration(): {
  subject: string;
  publicKey: string;
  privateKey: string;
} | null {
  const publicKey = env("WEB_PUSH_VAPID_PUBLIC_KEY");
  const privateKey = env("WEB_PUSH_VAPID_PRIVATE_KEY");
  if (!publicKey || !privateKey) return null;
  return {
    subject: env("WEB_PUSH_VAPID_SUBJECT") || "mailto:udefret12@gmail.com",
    publicKey,
    privateKey,
  };
}

async function sendWebPush(
  device: WebPushDevice,
  notification: NotificationRow,
): Promise<DeliveryResult> {
  const config = webPushConfiguration();
  if (!config) {
    return { ok: false, permanent: false, error: "Web Push no está configurado" };
  }

  webpush.setVapidDetails(
    config.subject,
    config.publicKey,
    config.privateKey,
  );
  try {
    await webpush.sendNotification(
      {
        endpoint: device.endpoint,
        keys: { p256dh: device.p256dh, auth: device.auth },
      },
      JSON.stringify({
        title: notification.title,
        body: notification.body,
        data: {
          notification_id: notification.id,
          type: notification.type,
          ...stringData(notification.payload),
        },
        url: "/enfermicambio/push/",
      }),
      { TTL: 120, urgency: "high" },
    );
    return { ok: true, permanent: false };
  } catch (error) {
    const statusCode = Number(
      (error as { statusCode?: number }).statusCode ?? 0,
    );
    const permanent = statusCode === 404 || statusCode === 410;
    return {
      ok: false,
      permanent,
      error: `Web Push ${statusCode || "error"}: ${String(error).slice(0, 500)}`,
    };
  }
}

function ntfyBaseUrl(): string {
  const configured = env("NTFY_BASE_URL") || "https://ntfy.sh";
  const parsed = new URL(configured);
  if (parsed.protocol !== "https:") {
    throw new Error("NTFY_BASE_URL debe usar HTTPS");
  }
  return parsed.toString().replace(/\/$/, "");
}

function ntfyTag(type: string): string {
  if (type.includes("workout")) return "running_shoe";
  if (type.includes("achievement") || type.includes("round")) return "trophy";
  if (type.includes("feed") || type.includes("social")) return "speech_balloon";
  if (type.includes("mission")) return "dart";
  return "loudspeaker";
}

async function sendNtfy(
  device: NtfyDevice,
  notification: NotificationRow,
): Promise<DeliveryResult> {
  if (!/^[A-Za-z0-9_-]{24,64}$/.test(device.topic)) {
    return { ok: false, permanent: true, error: "Tópico ntfy inválido" };
  }

  let baseUrl: string;
  try {
    // The database currently fixes this to ntfy.sh. Keeping the URL validation
    // here prevents a future row change from turning the dispatcher into an
    // arbitrary server-side request proxy.
    baseUrl = ntfyBaseUrl();
    const rowUrl = new URL(device.server_url);
    if (rowUrl.protocol !== "https:" || rowUrl.hostname !== new URL(baseUrl).hostname) {
      return { ok: false, permanent: false, error: "Servidor ntfy no autorizado" };
    }
  } catch (error) {
    return {
      ok: false,
      permanent: false,
      error: `Configuración ntfy inválida: ${String(error).slice(0, 300)}`,
    };
  }

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  const publishToken = env("NTFY_PUBLISH_TOKEN");
  if (publishToken) headers.Authorization = `Bearer ${publishToken}`;

  const response = await fetch(`${baseUrl}/`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      topic: device.topic,
      title: notification.title,
      message: notification.body,
      priority: 4,
      tags: [ntfyTag(notification.type)],
    }),
  });
  if (response.ok) return { ok: true, permanent: false };
  const errorBody = await response.text();
  const permanent = response.status === 401 || response.status === 403 || response.status === 404;
  return {
    ok: false,
    permanent,
    error: `ntfy ${response.status}: ${errorBody.slice(0, 500)}`,
  };
}

async function sendToDevice(
  device: PushDevice,
  notification: NotificationRow,
): Promise<DeliveryResult> {
  if (device.provider === "web") {
    return sendWebPush(device, notification);
  }
  if (device.provider === "ntfy") {
    return sendNtfy(device, notification);
  }
  return device.provider === "apns"
    ? sendApns(device, notification)
    : sendFcm(device, notification);
}

async function processOutbox(
  supabaseAdmin: AdminClient,
  outbox: OutboxRow,
): Promise<{ success: boolean; sent: number; disabled: number; error?: string }> {
  const { data: notification, error: notificationError } = await supabaseAdmin
    .from("notifications")
    .select("id, user_id, type, title, body, payload")
    .eq("id", outbox.notification_id)
    .maybeSingle();
  if (notificationError) throw new Error(notificationError.message);
  if (!notification) {
    await supabaseAdmin.rpc("finish_push_outbox", {
      p_id: outbox.id,
      p_success: true,
      p_error: null,
    });
    return { success: true, sent: 0, disabled: 0 };
  }

  const [nativeResult, webResult, ntfyResult] = await Promise.all([
    supabaseAdmin
      .from("push_devices")
      .select("token, platform, provider, app_id")
      .eq("user_id", outbox.user_id)
      .eq("enabled", true),
    supabaseAdmin
      .from("web_push_devices")
      .select("endpoint, p256dh, auth")
      .eq("user_id", outbox.user_id)
      .eq("enabled", true),
    supabaseAdmin
      .from("ntfy_devices")
      .select("topic, server_url")
      .eq("user_id", outbox.user_id)
      .eq("enabled", true),
  ]);
  if (nativeResult.error) throw new Error(nativeResult.error.message);
  if (webResult.error) throw new Error(webResult.error.message);
  if (ntfyResult.error) throw new Error(ntfyResult.error.message);

  const devices: PushDevice[] = [
    ...((nativeResult.data ?? []) as NativePushDevice[]),
    ...((webResult.data ?? []) as WebPushDevice[]).map((device) => ({
      ...device,
      provider: "web" as const,
    })),
    ...((ntfyResult.data ?? []) as Array<Omit<NtfyDevice, "provider">>).map((device) => ({
      ...device,
      provider: "ntfy" as const,
    })),
  ];

  if ((devices?.length ?? 0) === 0) {
    const error = 'No hay dispositivos registrados para este usuario';
    await supabaseAdmin.rpc('finish_push_outbox', {
      p_id: outbox.id,
      p_success: false,
      p_error: error,
    });
    return { success: false, sent: 0, disabled: 0, error };
  }

  let sent = 0;
  let disabled = 0;
  const errors: string[] = [];
  for (const raw of devices ?? []) {
    const device = raw as PushDevice;
    try {
      const result = await sendToDevice(device, notification as NotificationRow);
      if (result.ok) {
        sent++;
      } else {
        if (result.error) errors.push(result.error);
        if (result.permanent) {
          if (device.provider === "web") {
            await supabaseAdmin
              .from("web_push_devices")
              .update({ enabled: false })
              .eq("user_id", outbox.user_id)
              .eq("endpoint", device.endpoint);
          } else if (device.provider === "ntfy") {
            await supabaseAdmin
              .from("ntfy_devices")
              .update({ enabled: false, updated_at: new Date().toISOString() })
              .eq("user_id", outbox.user_id)
              .eq("topic", device.topic);
          } else {
            await supabaseAdmin
              .from("push_devices")
              .update({ enabled: false })
              .eq("token", device.token);
          }
          disabled++;
        }
      }
    } catch (error) {
      errors.push(error instanceof Error ? error.message : String(error));
    }
  }

  const success = sent > 0;
  await supabaseAdmin.rpc("finish_push_outbox", {
    p_id: outbox.id,
    p_success: success,
    p_error: success ? null : errors.join("; ").slice(0, 2000),
  });
  return {
    success,
    sent,
    disabled,
    ...(errors.length > 0 ? { error: errors.join("; ").slice(0, 500) } : {}),
  };
}

async function handle(
  supabaseAdmin: AdminClient,
  request: Request,
): Promise<Response> {
  if (!(await dispatchKeyIsValid(supabaseAdmin, request))) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = jsonObject(await request.json().catch(() => ({})));
  const notificationId = typeof body.notification_id === "string"
    ? body.notification_id
    : null;
  const { data: rows, error } = await supabaseAdmin.rpc("claim_push_outbox", {
    p_notification_id: notificationId,
    p_limit: notificationId ? 1 : 25,
  });
  if (error) return Response.json({ error: error.message }, { status: 500 });

  const results = [];
  for (const row of (rows ?? []) as OutboxRow[]) {
    results.push(await processOutbox(supabaseAdmin, row));
  }
  return Response.json({ processed: results.length, results });
}

export default {
  fetch: withSupabase(
    { auth: "none" },
    async (request, ctx) => {
      try {
        return await handle(ctx.supabaseAdmin, request);
      } catch (error) {
        return Response.json(
          { error: error instanceof Error ? error.message : String(error) },
          { status: 500 },
        );
      }
    },
  ),
};
