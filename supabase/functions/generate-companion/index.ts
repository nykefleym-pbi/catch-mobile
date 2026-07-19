// Supabase Edge Function: generate-companion
//
// The ONLY place that talks to the image-generation provider. The client never
// holds the provider key. Flow (docs/architecture/07-ai-pipeline.md, ADR 0001):
//
//   1. Authenticate the caller (anonymous sign-in users are authenticated).
//   2. Enforce a gentle per-user/day generation cap (free-tier friendly).
//   3. Generate a stylized companion from the source photo so it echoes the real
//      cat's colours/markings.
//   4. Attach descriptive metadata (coat, pattern, eyes, tail, markings, a
//      personality trait, a name).
//   5. Store the sprite in the public `sprites` bucket.
//   6. Persist cats + care_state; mark the capture complete.
//
// PROVIDER is pluggable via the IMAGE_PROVIDER env var (when unset we prefer
// "pixellab" if its token is configured, otherwise "cloudflare"):
//   - "pixellab" → read the real cat's characteristics with Cloudflare's free
//     vision model (LLaVA), then generate a PIXEL-ART companion from that
//     description via PixelLab (transparent background). This is the current
//     art direction.
//   - "cloudflare" → Cloudflare Workers AI Stable-Diffusion img2img
//     (free within a daily allowance) + locally-generated metadata.
//   - "gemini" → Gemini 2.5 Flash Image ("nano-banana") + Gemini JSON metadata.
//     Kept fully wired so we can switch back once Gemini billing is enabled.
//
// PRIVACY: the raw source photo is sent inline and is NEVER written to storage.
// Generation happens in-memory and the bytes are discarded when the request
// ends — the strongest form of "delete the source after generation".
//
// The provider's own safety filters are the moderation backstop for this slice;
// dedicated image moderation and true alpha-cutout (rembg) are hardening
// follow-ups.

import { createClient } from "jsr:@supabase/supabase-js@2";

const TRAIT_IDS = [
  "curious", "brave", "lazy", "foodie", "mischievous",
  "elegant", "playful", "protective", "explorer", "shy",
] as const;

// Gentle daily ceiling per user — well under free-tier provider limits.
const DAILY_CAP = 30;

// Hard timeouts on every external call so a stalled request fails fast with a
// clear error instead of burning to the ~150s platform wall-clock limit. The
// image timeout is per attempt: the Cloudflare path may try img2img and then a
// text-to-image fallback, so two of these must still fit comfortably under the
// wall clock alongside auth + upload.
const IMAGE_TIMEOUT_MS = 45_000;
const TEXT_TIMEOUT_MS = 20_000;
// Cloudflare vision (LLaVA) reads the cat's characteristics for the PixelLab path.
const VISION_TIMEOUT_MS = 30_000;
// Timeout for the quick Supabase round-trips (auth, cap count, inserts, upload)
// so a stalled control-plane call can't silently eat the whole request budget.
const DB_TIMEOUT_MS = 15_000;
const UPLOAD_TIMEOUT_MS = 30_000;

// Which backend generates the sprite. If IMAGE_PROVIDER is unset we prefer
// PixelLab when its token is configured (the pixel-art direction), otherwise
// Cloudflare. Set IMAGE_PROVIDER explicitly ("pixellab" | "cloudflare" |
// "gemini") to force one.
const EXPLICIT_PROVIDER = Deno.env.get("IMAGE_PROVIDER")?.toLowerCase();

const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const IMAGE_MODEL = "gemini-2.5-flash-image";
const TEXT_MODEL = "gemini-2.5-flash";

// Cloudflare Workers AI: img2img so the sprite is conditioned on the real photo.
// SDXL-Lightning is fast and accepts a base64 source image; override the model
// via CLOUDFLARE_IMAGE_MODEL (e.g. @cf/runwayml/stable-diffusion-v1-5-img2img).
const CF_BASE = "https://api.cloudflare.com/client/v4/accounts";
const CF_IMAGE_MODEL =
  Deno.env.get("CLOUDFLARE_IMAGE_MODEL") ??
  "@cf/bytedance/stable-diffusion-xl-lightning";
// Free Cloudflare vision model — reads the real cat into a short description
// which the PixelLab path turns into a pixel-art prompt.
const CF_VISION_MODEL =
  Deno.env.get("CLOUDFLARE_VISION_MODEL") ?? "@cf/llava-hf/llava-1.5-7b-hf";

// PixelLab: text-to-pixel-art. We describe the caught cat, then generate a
// pixel-art companion from that description (the source photo never leaves as
// an image). https://api.pixellab.ai/v1
const PIXELLAB_BASE = "https://api.pixellab.ai/v1";

interface GenerateRequest {
  imageBase64: string;
  mimeType?: string;
  detection?: Record<string, unknown>;
  // Coarse "where you met them" location for the Explore map. Optional — a catch
  // with location off omits these. Fuzzed to ~1 km before persistence (below).
  lat?: number;
  lng?: number;
}

// Round a device coordinate to a neighbourhood-level point (~1.1 km at 2 dp)
// before it is stored. Precise coordinates are never persisted (ADR 0001).
// Returns null for anything out of range or not a finite number.
function fuzzCoord(value: unknown, max: number): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  if (value < -max || value > max) return null;
  return Math.round(value * 100) / 100;
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
  const cfAccount = cfAccountId(Deno.env.get("CLOUDFLARE_ACCOUNT_ID"));
  const cfToken = Deno.env.get("CLOUDFLARE_API_TOKEN");
  const pixellabToken = Deno.env.get("PIXELLAB_API_TOKEN");
  const provider = EXPLICIT_PROVIDER ??
    (pixellabToken ? "pixellab" : "cloudflare");

  // --- 1. Authenticate the caller ------------------------------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  let userId: string;
  try {
    const { data: userData, error: userErr } = await withTimeout(
      userClient.auth.getUser(),
      DB_TIMEOUT_MS,
      "auth",
    );
    if (userErr || !userData.user) {
      log(`auth failed: ${userErr?.message ?? "no user"}`);
      return json({ error: "unauthorized" }, 401);
    }
    userId = userData.user.id;
  } catch (error) {
    // A stalled auth round-trip must not hang to the wall clock.
    const message = error instanceof Error ? error.message : String(error);
    log(`auth error: ${message}`);
    return json({ error: "auth_unavailable", detail: message }, 504);
  }
  log(`authed user ${userId}`);

  // The active provider must have its credentials configured.
  if (provider === "gemini") {
    if (!geminiKey) {
      log("GEMINI_API_KEY missing");
      return json({ error: "generation_unconfigured" }, 503);
    }
  } else if (provider === "pixellab") {
    // PixelLab makes the sprite; Cloudflare's free vision model reads the cat.
    if (!pixellabToken || !cfAccount || !cfToken) {
      log("PIXELLAB_API_TOKEN or Cloudflare vision creds missing");
      return json({ error: "generation_unconfigured" }, 503);
    }
  } else if (!cfAccount || !cfToken) {
    log("CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN missing");
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
  const geoLat = fuzzCoord(body.lat, 90);
  const geoLng = fuzzCoord(body.lng, 180);
  log(`body parsed, image ~${Math.round(body.imageBase64.length / 1024)}KB b64`);

  const db = createClient(supabaseUrl, serviceKey);

  // --- 2. Per-user daily cap -----------------------------------------------
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  try {
    const { count } = await withTimeout(
      db
        .from("cats")
        .select("id", { count: "exact", head: true })
        .eq("profile_id", userId)
        .gte("discovered_at", since),
      DB_TIMEOUT_MS,
      "daily_cap",
    );
    if ((count ?? 0) >= DAILY_CAP) {
      return json({ error: "daily_cap_reached", cap: DAILY_CAP }, 429);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    log(`daily cap check failed: ${message}`);
    return json({ error: "generation_unavailable", detail: message }, 504);
  }

  let captureId: string;
  try {
    const { data: capture, error: capErr } = await withTimeout(
      db
        .from("captures")
        .insert({
          profile_id: userId,
          status: "generating",
          detection_result: body.detection ?? null,
        })
        .select("id")
        .single(),
      DB_TIMEOUT_MS,
      "capture_insert",
    );
    if (capErr || !capture) {
      log(`capture insert failed: ${capErr?.message}`);
      return json({ error: "capture_write_failed", detail: capErr?.message }, 500);
    }
    captureId = capture.id as string;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    log(`capture insert error: ${message}`);
    return json({ error: "capture_write_failed", detail: message }, 500);
  }
  log(`capture ${captureId} created`);

  try {
    // --- 3. Generate the sprite (+ metadata) -------------------------------
    // Gemini reads the photo into structured attributes; Stable Diffusion can't,
    // so the Cloudflare path names the cat locally; the PixelLab path reads the
    // real cat with Cloudflare vision and turns that into a pixel-art prompt.
    let sprite: Uint8Array;
    let meta: CompanionMeta;
    if (provider === "gemini") {
      sprite = await generateSpriteGemini(geminiKey!, body.imageBase64, mimeType);
      meta = await describeCat(geminiKey!, body.imageBase64, mimeType);
    } else if (provider === "pixellab") {
      const described = await describeCatVision(
        cfAccount!,
        cfToken!,
        body.imageBase64,
      );
      log(`vision described: ${described || "(none)"}`);
      sprite = await generateSpritePixellab(pixellabToken!, described);
      meta = localMeta();
      if (described) meta.blurb = described;
    } else {
      sprite = await generateSpriteCloudflare(
        cfAccount!,
        cfToken!,
        body.imageBase64,
        mimeType,
      );
      meta = localMeta();
    }
    log(`sprite generated (${sprite.byteLength} bytes via ${provider})`);
    const traitId = TRAIT_IDS.includes(meta.trait_id as typeof TRAIT_IDS[number])
      ? meta.trait_id
      : TRAIT_IDS[Math.floor(Math.random() * TRAIT_IDS.length)];
    log(`meta ready: ${meta.name} / ${traitId}`);

    // --- 5. Store the sprite -----------------------------------------------
    const path = `${userId}/${captureId}.png`;
    const { error: upErr } = await withTimeout(
      db.storage
        .from("sprites")
        .upload(path, sprite, { contentType: "image/png", upsert: true }),
      UPLOAD_TIMEOUT_MS,
      "sprite_upload",
    );
    if (upErr) throw new Error(`sprite_upload_failed: ${upErr.message}`);
    const { data: pub } = db.storage.from("sprites").getPublicUrl(path);
    const spriteUrl = pub.publicUrl;
    log(`sprite uploaded: ${spriteUrl}`);

    // --- 6. Persist cat + care_state ---------------------------------------
    const { data: cat, error: catErr } = await withTimeout(
      db
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
          geo_lat: geoLat,
          geo_lng: geoLng,
        })
        .select(
          "id, name, sprite_url, trait_id, generation_meta, geo_lat, geo_lng, discovered_at",
        )
        .single(),
      DB_TIMEOUT_MS,
      "cat_insert",
    );
    if (catErr || !cat) throw new Error(`cat_write_failed: ${catErr?.message}`);

    await withTimeout(
      db.from("care_state").insert({ cat_id: cat.id, profile_id: userId }),
      DB_TIMEOUT_MS,
      "care_state_insert",
    );
    await withTimeout(
      db.from("captures").update({ status: "complete" }).eq("id", captureId),
      DB_TIMEOUT_MS,
      "capture_complete",
    );
    log(`done, cat ${cat.id}`);

    return json({ cat }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    log(`generation_failed: ${message}`);
    // Persist the reason on the capture so failures are diagnosable via SQL
    // even without access to function stdout.
    await withTimeout(
      db.from("captures").update({
        status: "failed",
        detection_result: { ...(body.detection ?? {}), error: message },
      }).eq("id", captureId),
      DB_TIMEOUT_MS,
      "capture_fail",
    ).catch((e) => log(`failed to record failure: ${e}`));
    return json({ error: "generation_failed", detail: message }, 502);
  }
});

// --- Cloudflare Workers AI: image stylization (img2img) --------------------

// The Cloudflare Account ID is a 32-char hex string. Be forgiving if the secret
// was pasted as the full dashboard URL (…/<accountId>/…) or with stray
// whitespace — extract the bare id so the API path resolves either way.
function cfAccountId(raw: string | undefined): string | undefined {
  if (!raw) return raw;
  const match = raw.match(/[0-9a-fA-F]{32}/);
  return (match ? match[0] : raw.trim());
}

async function generateSpriteCloudflare(
  accountId: string,
  token: string,
  imageBase64: string,
  _mimeType: string,
): Promise<Uint8Array> {
  // Clean cel-shaded game-sprite look (the "Pokémon-ish" art language) but with
  // FIDELITY prioritised: the sprite must stay recognisably the same cat, so the
  // prompt asks to preserve the real coat colour/markings and explicitly avoids
  // "vibrant/saturated" cues that make Stable Diffusion invent fantasy colours.
  // SD responds best to compact, comma-separated style tags.
  const prompt =
    "cute chibi cartoon cat, flat 2d storybook illustration, clean " +
    "creature-collector game sprite, thick soft outlines, flat matte cel " +
    "shading, big friendly eyes, full body, sitting, centered, facing viewer, " +
    "keep the cat's real natural fur colour and markings, natural realistic " +
    "cat colours, plain solid soft cream background, adorable, high quality";
  // Negatives do the heavy lifting: kill invented fantasy colours (Butter went
  // purple/teal, Gizmo lost its white), background glows/halos (Gizmo's circle),
  // and the earlier floating-face / duplicate artifacts. The photoreal/painterly
  // block pushes the output toward flat cartoon (Pebble came back semi-realistic)
  // WITHOUT raising img2img strength, which is what drifts the real cat's colour.
  const negativePrompt =
    "photorealistic, realistic photo, 3d render, painterly, semi-realistic, " +
    "hyperrealistic, detailed fur texture, individual fur strands, " +
    "unnatural fur color, neon colors, purple fur, teal fur, blue fur, rainbow, " +
    "oversaturated, fantasy creature, monster, glow, halo, circle, spotlight, " +
    "radial gradient, background pattern, decorations, stickers, multiple " +
    "animals, two cats, extra cats, floating faces, duplicate heads, extra " +
    "heads, text, letters, watermark, logo, signature, frame, border, " +
    "blurry, grainy, deformed, extra limbs, extra tails, low quality, " +
    "jpeg artifacts";

  // Prefer img2img so the sprite echoes the real cat's colours/markings. A LOWER
  // strength keeps it closer to the source photo (SD img2img: higher strength =
  // further from the input), which is what preserves the real cat. Some SDXL
  // endpoints are slow/unreliable with a source image, so if img2img errors or
  // times out we fall back to text-to-image — a cozy sprite still beats a failed
  // catch. (The metadata is generated locally either way.)
  try {
    return await cfImageRun(accountId, token, {
      prompt,
      negative_prompt: negativePrompt,
      // strength ~0.45 restyles into a clean sprite while staying close enough to
      // the source that the cat's real coat colour and markings carry through.
      image_b64: imageBase64,
      strength: 0.45,
      // Higher guidance makes SD follow the cartoon prompt harder — more
      // stylised — without the colour drift a higher strength would cause.
      guidance: 8.0,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.log(
      `[gen] cloudflare img2img failed (${message}); retrying text-to-image`,
    );
    return await cfImageRun(accountId, token, {
      prompt,
      negative_prompt: negativePrompt,
      guidance: 8.0,
    });
  }
}

// One Cloudflare Workers AI image call. The abort timer stays armed through the
// body read (see fetchWithTimeout) so a response that returns headers and then
// stalls its PNG stream still fails fast instead of hanging to the wall clock.
async function cfImageRun(
  accountId: string,
  token: string,
  payload: Record<string, unknown>,
): Promise<Uint8Array> {
  return await fetchWithTimeout(
    `${CF_BASE}/${accountId}/ai/run/${CF_IMAGE_MODEL}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(payload),
    },
    IMAGE_TIMEOUT_MS,
    async (res) => {
      // On success SD models stream raw PNG bytes; on failure Cloudflare returns
      // a JSON error envelope. Branch on that so failures surface readably.
      const contentType = res.headers.get("content-type") ?? "";
      if (!res.ok || contentType.includes("application/json")) {
        throw new Error(`image_api_${res.status}: ${await safeText(res)}`);
      }
      const bytes = new Uint8Array(await res.arrayBuffer());
      if (bytes.byteLength === 0) throw new Error("image_api_empty_response");
      return bytes;
    },
  );
}

// --- PixelLab: text-to-pixel-art -------------------------------------------

// Generate a pixel-art companion from a description of the real cat. PixelLab's
// pixflux endpoint is text-to-image; `no_background: true` yields a transparent
// sprite. Response carries the PNG as base64 — we're forgiving about its shape.
async function generateSpritePixellab(
  token: string,
  description: string,
): Promise<Uint8Array> {
  const subject = description.length > 0 ? description : "a cute cat";
  const prompt =
    `cute pixel art cat, ${subject}, adorable chibi game companion sprite, ` +
    `sitting, front view, centered, friendly big eyes`;
  const data = await fetchWithTimeout(
    `${PIXELLAB_BASE}/generate-image-pixflux`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        description: prompt,
        image_size: { width: 128, height: 128 },
        negative_description:
          "blurry, realistic photo, deformed, extra limbs, text, watermark, " +
          "multiple cats, human",
        text_guidance_scale: 8.0,
        no_background: true,
      }),
    },
    IMAGE_TIMEOUT_MS,
    async (res) => {
      if (!res.ok) {
        throw new Error(`image_api_${res.status}: ${await safeText(res)}`);
      }
      return await res.json();
    },
  );
  const b64 = data?.image?.base64 ?? data?.image ??
    data?.images?.[0]?.base64 ?? data?.images?.[0];
  if (typeof b64 !== "string" || b64.length === 0) {
    throw new Error("image_api_no_image");
  }
  return decodeBase64(stripDataUri(b64));
}

// Read the real cat's appearance into a short description using Cloudflare's
// free vision model. Non-fatal: on any failure we return "" and PixelLab still
// draws a (less specific) cat, so a catch never fails over the describe step.
async function describeCatVision(
  accountId: string,
  token: string,
  imageBase64: string,
): Promise<string> {
  try {
    const bytes = decodeBase64(imageBase64);
    const data = await fetchWithTimeout(
      `${CF_BASE}/${accountId}/ai/run/${CF_VISION_MODEL}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          image: Array.from(bytes),
          prompt:
            "Describe only this cat's appearance in one short vivid phrase: " +
            "coat colour, fur pattern, eye colour, and any distinctive " +
            "markings. Do not mention the background or surroundings.",
          max_tokens: 200,
        }),
      },
      VISION_TIMEOUT_MS,
      async (res) => (res.ok ? await res.json() : null),
    );
    return (data?.result?.description ?? "").toString().trim();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.log(`[gen] vision describe failed (${message}); using generic`);
    return "";
  }
}

// --- Gemini: image stylization ---------------------------------------------

async function generateSpriteGemini(
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

  const data = await fetchWithTimeout(
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
        // Image models are multimodal-by-design: IMAGE-only is rejected, so we
        // must ask for TEXT + IMAGE and pick the image part out of the reply.
        generationConfig: { responseModalities: ["TEXT", "IMAGE"] },
      }),
    },
    IMAGE_TIMEOUT_MS,
    async (res) => {
      if (!res.ok) {
        throw new Error(`image_api_${res.status}: ${await safeText(res)}`);
      }
      return await res.json();
    },
  );

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
    const data = await fetchWithTimeout(
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
      async (res) => (res.ok ? await res.json() : null),
    );
    if (!data) return fallbackMeta();
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

// Cozy names for the Cloudflare path, where the image model can't read the photo
// into attributes. Keeps every catch feeling distinct instead of "Mystery Cat".
const LOCAL_NAMES = [
  "Mochi", "Biscuit", "Pumpkin", "Waffles", "Pepper", "Marshmallow", "Clover",
  "Nimbus", "Peaches", "Sesame", "Ziggy", "Butter", "Pickles", "Maple",
  "Dumpling", "Snickers", "Cinnamon", "Toffee", "Noodle", "Pudding", "Gizmo",
  "Bramble", "Poppy", "Tofu", "Muffin", "Hazel", "Nugget", "Basil", "Clementine",
  "Sprout", "Custard", "Jellybean", "Pebble", "Cricket", "Tater", "Blossom",
  "Cocoa", "Dill", "Fig", "Honey",
];

// Warm, trait-flavoured backstories so every locally-named cat still reads as a
// little character. Keyed by trait so the blurb matches the personality chip.
const TRAIT_BLURBS: Record<string, string> = {
  curious:
    "Nose into everything, this one — every open door is a mystery worth solving.",
  brave:
    "Fears neither vacuum nor thunder; guards the windowsill like a tiny, fearless knight.",
  lazy:
    "A connoisseur of sunbeams and long afternoons, with a full-time career in napping.",
  foodie:
    "Believes every doorstep hides a snack, and greets each meal like a small festival.",
  mischievous:
    "Knocks pens off tables purely for science, then blinks at you with total innocence.",
  elegant:
    "Moves like poured cream and expects — quite reasonably — to be admired.",
  playful:
    "Would chase a leaf to the ends of the earth, then present it to you as treasure.",
  protective:
    "Keeps a careful eye on their people and their patch, always first to check a noise.",
  explorer:
    "Maps the whole neighbourhood one fence at a time, home only for dinner and a debrief.",
  shy:
    "Watches from beneath the sofa at first — but win them over and you have a friend for life.",
};

function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function localMeta(): CompanionMeta {
  const trait = pick(TRAIT_IDS);
  return {
    name: pick(LOCAL_NAMES),
    coat_color: "unknown",
    pattern: "unknown",
    eye_color: "unknown",
    tail: "unknown",
    markings: "none noted",
    trait_id: trait,
    blurb: TRAIT_BLURBS[trait] ??
      "A soft-hearted wanderer who picked your neighbourhood to call home.",
  };
}

// --- helpers ---------------------------------------------------------------

// Fetch with a single abort timer that covers BOTH the request and the body
// read: `consume` runs while the timer is still armed, so a response that sends
// headers and then stalls its stream still aborts at the timeout instead of
// hanging to the platform wall-clock limit.
async function fetchWithTimeout<T>(
  url: string,
  init: RequestInit,
  timeoutMs: number,
  consume: (res: Response) => Promise<T>,
): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...init, signal: controller.signal });
    return await consume(res);
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error(`provider_timeout_after_${timeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

// Races an arbitrary promise (e.g. a Supabase query builder, which is thenable)
// against a timeout so a stalled control-plane call rejects with a labelled
// error instead of silently eating the request budget.
function withTimeout<T>(p: PromiseLike<T>, ms: number, label: string): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`${label}_timeout_after_${ms}ms`)),
      ms,
    );
    Promise.resolve(p).then(
      (v) => {
        clearTimeout(timer);
        resolve(v);
      },
      (e) => {
        clearTimeout(timer);
        reject(e);
      },
    );
  });
}

function decodeBase64(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// Strip a `data:image/...;base64,` prefix if the provider returned a data URI.
function stripDataUri(b64: string): string {
  const comma = b64.indexOf(",");
  return b64.startsWith("data:") && comma !== -1 ? b64.slice(comma + 1) : b64;
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
