/**
 * notify-technician
 *
 * Llamada desde la app iOS después de guardar un diagnóstico.
 * Busca el técnico asignado al agricultor y le envía una push APNs.
 *
 * Secrets necesarios en Supabase Dashboard → Edge Functions → Secrets:
 *   APNS_KEY_ID        — ID de la APNs Auth Key (10 caracteres)
 *   APNS_TEAM_ID       — Apple Team ID (10 caracteres)
 *   APNS_PRIVATE_KEY   — Contenido del .p8 SIN encabezado/pie, sin saltos de línea
 *   APNS_BUNDLE_ID     — com.chochesanchez.KafeCam
 *   APNS_SANDBOX       — "true" para desarrollo, "false" para producción
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BUNDLE_ID  = Deno.env.get("APNS_BUNDLE_ID")  ?? "com.chochesanchez.KafeCam";
const KEY_ID     = Deno.env.get("APNS_KEY_ID")!;
const TEAM_ID    = Deno.env.get("APNS_TEAM_ID")!;
const PRIVATE_KEY_B64 = Deno.env.get("APNS_PRIVATE_KEY")!;
const SANDBOX    = Deno.env.get("APNS_SANDBOX") === "true";

const APNS_HOST  = SANDBOX
  ? "api.sandbox.push.apple.com"
  : "api.push.apple.com";

// ─── JWT para APNs (token-based auth) ────────────────────────────────────────

function base64url(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function makeApnsJwt(): Promise<string> {
  const header  = base64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: KEY_ID })));
  const payload = base64url(new TextEncoder().encode(JSON.stringify({ iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) })));
  const message = `${header}.${payload}`;

  // Import PKCS#8 key stored as raw base64 (no PEM headers)
  const keyBytes = Uint8Array.from(atob(PRIVATE_KEY_B64), (c) => c.charCodeAt(0));
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const sigBuffer = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    privateKey,
    new TextEncoder().encode(message),
  );

  return `${message}.${base64url(new Uint8Array(sigBuffer))}`;
}

// ─── Enviar push ──────────────────────────────────────────────────────────────

async function sendPush(deviceToken: string, title: string, body: string, data: Record<string, string>) {
  const jwt = await makeApnsJwt();

  const payload = {
    aps: { alert: { title, body }, sound: "default", badge: 1 },
    ...data,
  };

  const resp = await fetch(`https://${APNS_HOST}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`APNs error ${resp.status}: ${text}`);
  }
}

// ─── Handler ──────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, content-type" } });
  }

  try {
    const { farmer_id, capture_id, prediction } = await req.json() as {
      farmer_id: string;
      capture_id: string;
      prediction: string;
    };

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1. Buscar técnico asignado al agricultor
    const { data: link } = await supabase
      .from("technician_farmers")
      .select("technician_id")
      .eq("farmer_id", farmer_id)
      .limit(1)
      .single();

    if (!link?.technician_id) {
      return new Response(JSON.stringify({ skipped: "no_technician" }), { status: 200 });
    }

    // 2. Obtener nombre del agricultor y token del técnico
    const [{ data: farmerProfile }, { data: techProfile }] = await Promise.all([
      supabase.from("profiles").select("name").eq("id", farmer_id).single(),
      supabase.from("profiles").select("apns_token").eq("id", link.technician_id).single(),
    ]);

    const apnsToken = techProfile?.apns_token;
    if (!apnsToken) {
      return new Response(JSON.stringify({ skipped: "no_apns_token" }), { status: 200 });
    }

    const farmerName = farmerProfile?.name ?? "Un agricultor";

    await sendPush(
      apnsToken,
      `Nuevo diagnóstico de ${farmerName}`,
      prediction,
      { capture_id, farmer_id },
    );

    return new Response(JSON.stringify({ sent: true }), { status: 200 });
  } catch (err) {
    console.error("[notify-technician]", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
