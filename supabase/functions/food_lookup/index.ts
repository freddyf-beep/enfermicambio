import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPEN_FOOD_FACTS_FIELDS = [
  "product_name",
  "brands",
  "serving_quantity",
  "serving_quantity_unit",
  "serving_size",
  "nutriments",
  "nutrition",
].join(",");

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "private, max-age=300",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return jsonResponse({}, 204);
  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405);
  }

  let barcode = "";
  try {
    const body = await req.json() as { barcode?: unknown };
    barcode = String(body.barcode ?? "").replace(/[\s-]/g, "");
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!/^(\d{8}|\d{12}|\d{13}|\d{14})$/.test(barcode)) {
    return jsonResponse({ error: "invalid_barcode" }, 400);
  }

  const endpoint = new URL(
    `https://world.openfoodfacts.org/api/v3/product/${barcode}`,
  );
  endpoint.searchParams.set("fields", OPEN_FOOD_FACTS_FIELDS);

  try {
    const upstream = await fetch(endpoint, {
      headers: {
        "Accept": "application/json",
        "User-Agent":
          "EnfermiCambio/1.1 (https://github.com/freddyf-beep/enfermicambio)",
      },
      signal: AbortSignal.timeout(10_000),
    });
    if (upstream.status === 404) {
      return jsonResponse({ status: "not_found" });
    }
    if (!upstream.ok) {
      return jsonResponse({ error: "upstream_unavailable" }, 502);
    }
    const data = await upstream.json();
    return jsonResponse(data);
  } catch (error) {
    console.error("Open Food Facts lookup failed", error);
    return jsonResponse({ error: "upstream_unavailable" }, 502);
  }
});
