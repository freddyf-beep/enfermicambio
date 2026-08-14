import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.53.0/+esm";

const config = window.ENFERMICAMBIO_CONFIG || {};
const loginCard = document.querySelector("#login-card");
const deviceCard = document.querySelector("#device-card");
const loginForm = document.querySelector("#login-form");
const emailInput = document.querySelector("#email");
const passwordInput = document.querySelector("#password");
const userName = document.querySelector("#user-name");
const supportMessage = document.querySelector("#support-message");
const status = document.querySelector("#status");
const subscribeButton = document.querySelector("#subscribe-button");
const unsubscribeButton = document.querySelector("#unsubscribe-button");
const logoutButton = document.querySelector("#logout-button");

let client = null;
let registration = null;

function setStatus(message, isError = false) {
  status.textContent = message;
  status.classList.toggle("error", isError);
}

function isConfigured() {
  return Boolean(
    config.SUPABASE_URL &&
      config.SUPABASE_ANON_KEY &&
      config.VAPID_PUBLIC_KEY &&
      !config.SUPABASE_URL.includes("YOUR_PROJECT") &&
      !config.VAPID_PUBLIC_KEY.includes("YOUR_WEB_PUSH"),
  );
}

function isStandalone() {
  return window.matchMedia?.("(display-mode: standalone)").matches ||
    window.navigator.standalone === true;
}

function isIPhone() {
  return /iPhone|iPad|iPod/i.test(navigator.userAgent);
}

function base64ToBytes(value) {
  const padding = "=".repeat((4 - (value.length % 4)) % 4);
  const base64 = (value + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(base64);
  return Uint8Array.from([...raw].map((char) => char.charCodeAt(0)));
}

async function ensureServiceWorker() {
  registration = await navigator.serviceWorker.register("./sw.js", { scope: "./" });
  await navigator.serviceWorker.ready;
  return registration;
}

async function currentSubscription() {
  if (!registration) await ensureServiceWorker();
  return registration.pushManager.getSubscription();
}

async function updateSubscriptionButton() {
  if (!client || !client.auth.getUser) return;
  try {
    const subscription = await currentSubscription();
    const active = Boolean(subscription);
    subscribeButton.textContent = active
      ? "Actualizar avisos en este iPhone"
      : "Activar avisos en este iPhone";
    unsubscribeButton.classList.toggle("hidden", !active);
  } catch (_) {
    subscribeButton.textContent = "Activar avisos en este iPhone";
  }
}

async function renderSession(session) {
  const signedIn = Boolean(session);
  loginCard.classList.toggle("hidden", signedIn);
  deviceCard.classList.toggle("hidden", !signedIn);
  if (!signedIn) {
    userName.textContent = "—";
    supportMessage.textContent = "";
    return;
  }

  const { data: profile } = await client
    .from("profiles")
    .select("display_name")
    .eq("id", session.user.id)
    .maybeSingle();
  userName.textContent = profile?.display_name || session.user.email || "Usuario";
  if (isIPhone() && !isStandalone()) {
    supportMessage.textContent =
      "En iPhone primero añade esta página a la pantalla de inicio y abre el icono instalado.";
  } else {
    supportMessage.textContent =
      "Este dispositivo quedará registrado para avisos privados del grupo.";
  }
  await updateSubscriptionButton();
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!client) return;
  const button = loginForm.querySelector("button");
  button.disabled = true;
  setStatus("Iniciando sesión…");
  const { data, error } = await client.auth.signInWithPassword({
    email: emailInput.value.trim(),
    password: passwordInput.value,
  });
  button.disabled = false;
  if (error) {
    setStatus(`No se pudo iniciar sesión: ${error.message}`, true);
    return;
  }
  setStatus("Sesión iniciada.");
  await renderSession(data.session);
});

subscribeButton.addEventListener("click", async () => {
  if (!client) return;
  if (isIPhone() && !isStandalone()) {
    setStatus("En iPhone abre el icono añadido a la pantalla de inicio y vuelve a pulsar el botón.", true);
    return;
  }
  if (!window.isSecureContext || !("serviceWorker" in navigator) || !("PushManager" in window)) {
    setStatus("Este navegador no ofrece Web Push en este contexto.", true);
    return;
  }

  // iOS requires this request to originate from a visible user interaction.
  const permission = await Notification.requestPermission();
  if (permission !== "granted") {
    setStatus("El permiso fue rechazado. Actívalo en Ajustes → Notificaciones.", true);
    return;
  }

  subscribeButton.disabled = true;
  setStatus("Registrando este iPhone…");
  try {
    await ensureServiceWorker();
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: base64ToBytes(config.VAPID_PUBLIC_KEY),
      });
    }
    const json = subscription.toJSON();
    const keys = json.keys || {};
    const { error } = await client.rpc("register_web_push_device", {
      p_endpoint: subscription.endpoint,
      p_p256dh: keys.p256dh,
      p_auth: keys.auth,
      p_user_agent: navigator.userAgent,
    });
    if (error) throw error;
    setStatus("Avisos activados. Puedes cerrar Safari; iOS los mostrará en la pantalla bloqueada.");
    await updateSubscriptionButton();
  } catch (error) {
    setStatus(`No se pudo activar Web Push: ${error.message || error}`, true);
  } finally {
    subscribeButton.disabled = false;
  }
});

unsubscribeButton.addEventListener("click", async () => {
  try {
    const subscription = await currentSubscription();
    if (subscription) {
      await client.rpc("unregister_web_push_device", {
        p_endpoint: subscription.endpoint,
      });
      await subscription.unsubscribe();
    }
    setStatus("Avisos desactivados en este dispositivo.");
    await updateSubscriptionButton();
  } catch (error) {
    setStatus(`No se pudo desactivar: ${error.message || error}`, true);
  }
});

logoutButton.addEventListener("click", async () => {
  await client?.auth.signOut();
  setStatus("Sesión cerrada.");
});

async function start() {
  if (!isConfigured()) {
    setStatus("Falta la configuración pública del puente. No se inició ninguna suscripción.", true);
    return;
  }
  client = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);
  const { data } = await client.auth.getSession();
  await renderSession(data.session);
  client.auth.onAuthStateChange((_event, session) => renderSession(session));
}

start().catch((error) => setStatus(`No se pudo cargar el puente: ${error.message || error}`, true));
