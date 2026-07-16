// Supabase Edge Function: generate-companion
//
// The ONLY place that talks to the image-generation provider. The client never
// holds the provider key. Flow (docs/architecture/07-ai-pipeline.md, ADR 0001):
//
//   1. Authenticate the caller (anonymous sign-in users are authenticated).
//   2. Enforce a gentle per-user/day generation cap (free-tier friendly).
//   3. Generate a stylized companion with Gemini 2.5 Flash Image, conditioned on
//      the source photo so it echoes the real cat's colours/markings.
//   4. Extract non-identifying descriptive metadata (coat, pattern, eyes, tail,
//      markings, a personality trait, a name).
//   5. Store the sprite in the public `sprites` bucket.
//   6. Persist cats + care_state; mark the capture complete.
//
// PRIVACY: the raw source photo is sent inline and is NEVER written to storage.
// Generation happens in-memory and the bytes are discarded when the request
// ends — the strongest form of "delete the source after generation".
//
// Gemini safety filters are the moderation backstop for this slice; dedicated
// image moderation and true alpha-cutout (rembg) are hardening follow-ups.

import { createClient } from "jsr:@supabase/supabase-js@2";

const TRAIT_IDS = [
  "curious", "brave", "lazy", "foodie", "mischievous",
  "elegant", "playful", "protective", "explorer", "shy",
] as const;

// Gentle daily ceiling per user — well under free-tier provider limits.
const DAILY_CAP = 30;

// Hard timeouts on the provider calls so a stalled request fails fast with a
// clear error instead of burning to the ~150s platform wall-clock limit.
const IMAGE_TIMEOUT_MS = 75_000;
const TEXT_TIMEOUT_MS = 25_000;

const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const IMAGE_MODEL = "gemini-2.5-flash-image";
const TEXT_MODEL = "gemini-2.5-flash";

interface GenerateRequest {
  imageBase64: string;
  mimeType?: string;
  detection?: Record<string, unknown>;
}

interface CompanionMeta {
  name: string;
  coat_color: string;
  pattern: string;
  eye_color: string;
  tail: string;
  markings: string;
  trait_id: string;
  blurb: string;
}

Deno.serve(async (req: Request) => {
  const t0 = Date.now();
  const log = (msg: string) => console.log(`[gen +${Date.now() - t0}ms] ${msg}`);

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors() });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const geminiKey = Deno.env.get("GEMINI_API_KEY");

  // --- 1. Authenticate the caller ------------------------------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) {
    log(`auth failed: ${userErr?.message ?? "no user"}`);
    return json({ error: "unauthorized" }, 401);
  }
  const userId = userData.user.id;
  log(`authed user ${userId}`);

  if (!geminiKey) {
    log("GEMINI_API_KEY missing");
    return json({ error: "generation_unconfigured" }, 503);
  }

  let body: GenerateRequest;
  try {
    body = await req.json() as GenerateRequest;
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  if (!body.imageBase64) return json({ error: "missing_image" }, 400);
  const mimeType = body.mimeType ?? "image/jpeg";
  log(`body parsed, image ~${Math.round(body.imageBase64.length / 1024)}KB b64`);

  const db = createClient(supabaseUrl, serviceKey);

  // --- 2. Per-user daily cap -----------------------------------------------
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count } = await db
    .from("cats")
    .select("id", { count: "exact", head: true })
    .eq("profile_id", userId)
    .gte("discovered_at", since);
  if ((count ?? 0) >= DAILY_CAP) {
    return json({ error: "daily_cap_reached", cap: DAILY_CAP }, 429);
  }

  const { data: capture, error: capErr } = await db
    .from("captures")
    .insert({
      profile_id: userId,
      status: "generating",
      detection_result: body.detection ?? null,
    })
    .select("id")
    .single();
  if (capErr || !capture) {
    log(`capture insert failed: ${capErr?.message}`);
    return json({ error: "capture_write_failed", detail: capErr?.message }, 500);
  }
  const captureId = capture.id as string;
  log(`capture ${captureId} created`);

  try {
    // --- 3. Generate the sprite --------------------------------------------
    const sprite = await generateSprite(geminiKey, body.imageBase64, mimeType);
    log(`sprite generated (${sprite.byteLength} bytes)`);

    // --- 4. Extract descriptive metadata -----------------------------------
    const meta = await describeCat(geminiKey, body.imageBase64, mimeType);
    const traitId = TRAIT_IDS.includes(meta.trait_id as typeof TRAIT_IDS[number])
      ? meta.trait_id
      : TRAIT_IDS[Math.floor(Math.random() * TRAIT_IDS.length)];
    log(`meta ready: ${meta.name} / ${traitId}`);

    // --- 5. Store the sprite -----------------------------------------------
    const path = `${userId}/${captureId}.png`;
    const { error: upErr } = await db.storage
      .from("sprites")
      .upload(path, sprite, { contentType: "image/png", upsert: true });
    if (upErr) throw new Error(`sprite_upload_failed: ${upErr.message}`);
    const { data: pub } = db.storage.from("sprites").getPublicUrl(path);
    const spriteUrl = pub.publicUrl;
    log(`sprite uploaded: ${spriteUrl}`);

    // --- 6. Persist cat + care_state ---------------------------------------
    const { data: cat, error: catErr } = await db
      .from("cats")
      .insert({
        capture_id: captureId,
        profile_id: userId,
        name: meta.name,
        sprite_url: spriteUrl,
        trait_id: traitId,
        generation_meta: {
          coat_color: meta.coat_color,
          pattern: meta.pattern,
          eye_color: meta.eye_color,
          tail: meta.tail,
          markings: meta.markings,
          blurb: meta.blurb,
        },
      })
      .select("id, name, sprite_url, trait_id, generation_meta, discovered_at")
      .single();
    if (catErr || !cat) throw new Error(`cat_write_failed: ${catErr?.message}`);

    await db.from("care_state").insert({ cat_id: cat.id, profile_id: userId });
    await db.from("captures").update({ status: "complete" }).eq("id", captureId);
    log(`done, cat ${cat.id}`);

    return json({ cat }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    log(`generation_failed: ${message}`);
    await db.from("captures").update({ status: "failed" }).eq("id", captureId);
    return json({ error: "generation_failed", detail: message }, 502);
  }
});

// --- Gemini: image stylization ---------------------------------------------

async function generateSprite(
  key: string,
  imageBase64: string,
  mimeType: string,
): Promise<Uint8Array> {
  const prompt =
    "Turn the cat in this photo into an adorable, cozy mobile-game companion " +
    "sprite. Keep it recognizably the SAME cat: preserve its coat colour, fur " +
    "pattern, eye colour, ear and tail shape, and any distinctive markings. " +
    "Style: soft, warm, hand-illustrated chibi with gentle cel shading and a " +
    "friendly expression. Full body, sitting or standing, centered, facing the " +
    "viewer. Render on a fully transparent background. No text, no borders, no " +
    "watermark, no drop shadow on the ground.";

  const res = await fetchWithTimeout(
    `${GEMINI_BASE}/${IMAGE_MODEL}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inline_data: { mime_type: mimeType, data: imageBase64 } },
          ],
        }],
        generationConfig: { responseModalities: ["IMAGE"] },
      }),
    },
    IMAGE_TIMEOUT_MS,
  );

  if (!res.ok) {
    throw new Error(`image_api_${res.status}: ${await safeText(res)}`);
  }
  const data = await res.json();
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  for (const part of parts) {
    const inline = part.inlineData ?? part.inline_data;
    if (inline?.data) return decodeBase64(inline.data);
  }
  // Surface why no image came back (often a safety block or text-only reply).
  const finish = data?.candidates?.[0]?.finishReason ?? "unknown";
  const block = data?.promptFeedback?.blockReason ?? "none";
  throw new Error(`image_api_no_image (finish=${finish}, block=${block})`);
}

// --- Gemini: descriptive metadata (structured JSON) ------------------------

async function describeCat(
  key: string,
  imageBase64: string,
  mimeType: string,
): Promise<CompanionMeta> {
  const prompt =
    "Look at this cat and describe it as collectible game-companion attributes. " +
    "Invent a short, cute, friendly name (1-2 words). Pick the single personality " +
    "trait id that best fits its vibe. Keep every field concise.";

  const schema = {
    type: "object",
    properties: {
      name: { type: "string" },
      coat_color: { type: "string" },
      pattern: { type: "string" },
      eye_color: { type: "string" },
      tail: { type: "string" },
      markings: { type: "string" },
      trait_id: { type: "string", enum: [...TRAIT_IDS] },
      blurb: { type: "string" },
    },
    required: [
      "name", "coat_color", "pattern", "eye_color",
      "tail", "markings", "trait_id", "blurb",
    ],
  };

  try {
    const res = await fetchWithTimeout(
      `${GEMINI_BASE}/${TEXT_MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              { inline_data: { mime_type: mimeType, data: imageBase64 } },
            ],
          }],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: schema,
          },
        }),
      },
      TEXT_TIMEOUT_MS,
    );
    if (!res.ok) return fallbackMeta();
    const data = await res.json();
    const text = data?.candidates?.[0]?.content?.parts
      ?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";
    const parsed = JSON.parse(text) as CompanionMeta;
    if (!parsed.name) parsed.name = "Mystery Cat";
    return parsed;
  } catch {
    // Metadata is non-critical — never fail the whole catch over it.
    return fallbackMeta();
  }
}

function fallbackMeta(): CompanionMeta {
  return {
    name: "Mystery Cat",
    coat_color: "unknown",
    pattern: "unknown",
    eye_color: "unknown",
    tail: "unknown",
    markings: "none noted",
    trait_id: TRAIT_IDS[Math.floor(Math.random() * TRAIT_IDS.length)],
    blurb: "A cat of few words, but many mysteries.",
  };
}

// --- helpers ---------------------------------------------------------------

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error(`provider_timeout_after_${timeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

function decodeBase64(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function safeText(res: Response): Promise<string> {
  try {
    return (await res.text()).slice(0, 300);
  } catch {
    return "";
  }
}

function cors(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json", ...cors() },
  });
}
