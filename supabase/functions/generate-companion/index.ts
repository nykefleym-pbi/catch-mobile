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
// PROVIDER is pluggable via the IMAGE_PROVIDER env var:
//   - "cloudflare" (default) → Cloudflare Workers AI Stable-Diffusion img2img
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
// Timeout for the quick Supabase round-trips (auth, cap count, inserts, upload)
// so a stalled control-plane call can't silently eat the whole request budget.
const DB_TIMEOUT_MS = 15_000;
const UPLOAD_TIMEOUT_MS = 30_000;

// Which backend generates the sprite. Defaults to Cloudflare so the app works
// on a free tier; set IMAGE_PROVIDER=gemini to use nano-banana instead.
const IMAGE_PROVIDER = (Deno.env.get("IMAGE_PROVIDER") ?? "cloudflare").toLowerCase();

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
  const cfAccount = cfAccountId(Deno.env.get("CLOUDFLARE_ACCOUNT_ID"));
  const cfToken = Deno.env.get("CLOUDFLARE_API_TOKEN");

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
  if (IMAGE_PROVIDER === "gemini") {
    if (!geminiKey) {
      log("GEMINI_API_KEY missing");
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
    // --- 3. Generate the sprite --------------------------------------------
    const sprite = IMAGE_PROVIDER === "gemini"
      ? await generateSpriteGemini(geminiKey!, body.imageBase64, mimeType)
      : await generateSpriteCloudflare(
        cfAccount!,
        cfToken!,
        body.imageBase64,
        mimeType,
      );
    log(`sprite generated (${sprite.byteLength} bytes via ${IMAGE_PROVIDER})`);

    // --- 4. Attach descriptive metadata ------------------------------------
    // Gemini can read the photo into structured attributes; Stable Diffusion
    // can't, so the Cloudflare path names the cat locally.
    const meta = IMAGE_PROVIDER === "gemini"
      ? await describeCat(geminiKey!, body.imageBase64, mimeType)
      : localMeta();
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
        })
        .select("id, name, sprite_url, trait_id, generation_meta, discovered_at")
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
  // Pokémon-style creature art: a single centered character with clean bold
  // outlines and vibrant cel shading on a plain background. Stable Diffusion
  // responds best to compact, comma-separated style tags.
  const prompt =
    "official Pokemon-style creature sprite of a single cute cat, " +
    "monster-collecting game character art, clean thick bold outlines, " +
    "bright vibrant saturated colors, smooth cel shading, big expressive eyes, " +
    "full body, centered, facing viewer, plain solid pastel background, crisp, " +
    "high quality, adorable";
  // The negative prompt is what actually kills the earlier artifacts — the
  // floating extra cat-faces, duplicates, text, and busy/decorated backgrounds.
  const negativePrompt =
    "multiple animals, two cats, extra cats, floating faces, duplicate heads, " +
    "extra heads, text, letters, watermark, logo, signature, busy background, " +
    "cluttered, decorations, stickers, frame, border, photorealistic, realistic " +
    "photo, blurry, grainy, deformed, extra limbs, extra tails, low quality, " +
    "jpeg artifacts";

  // Prefer img2img so the sprite echoes the real cat's colours/markings. Some
  // SDXL endpoints are slow or unreliable when handed a source image, so if that
  // attempt errors or times out we fall back to text-to-image — a cozy sprite
  // still beats a failed catch. (The metadata is generated locally either way.)
  try {
    return await cfImageRun(accountId, token, {
      prompt,
      negative_prompt: negativePrompt,
      // strength ~0.65 restyles assertively toward the creature look while still
      // echoing the source photo's coat colour and markings.
      image_b64: imageBase64,
      strength: 0.65,
      guidance: 7.5,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.log(
      `[gen] cloudflare img2img failed (${message}); retrying text-to-image`,
    );
    return await cfImageRun(accountId, token, {
      prompt,
      negative_prompt: negativePrompt,
      guidance: 7.5,
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

const LOCAL_BLURBS = [
  "Found mid-adventure and ready for a cozy new chapter.",
  "Small paws, big personality — an instant favourite.",
  "Wandered in from the neighbourhood with plenty of charm.",
  "Curled up in your journal like it always belonged there.",
  "A soft-hearted explorer with a knack for finding sunbeams.",
];

function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function localMeta(): CompanionMeta {
  return {
    name: pick(LOCAL_NAMES),
    coat_color: "unknown",
    pattern: "unknown",
    eye_color: "unknown",
    tail: "unknown",
    markings: "none noted",
    trait_id: pick(TRAIT_IDS),
    blurb: pick(LOCAL_BLURBS),
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
