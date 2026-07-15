// Supabase Edge Function: generate-companion
//
// The ONLY place that talks to the image-generation provider. The client never
// holds the provider key. Responsibilities (see docs/architecture/07-ai-pipeline.md
// and docs/decisions/0001-image-generation.md):
//
//   1. Authenticate the caller.
//   2. Enforce rate limit + per-user/day cost cap (free-tier friendly).
//   3. Moderate the submitted image.
//   4. Generate a stylized companion (Gemini 2.5 Flash Image, free tier).
//   5. Remove background -> transparent PNG sprite (rembg / segmentation).
//   6. Store the sprite; persist cat + care_state rows.
//   7. Delete the raw source photo (we keep only the sprite).
//
// Phase 0 is a documented stub: the boundary, contract, and guard rails are
// expressed; the provider calls are TODO for Phase 1.

import { createClient } from "jsr:@supabase/supabase-js@2";

interface GenerateRequest {
  captureId: string;
  // The accepted image is uploaded to a short-lived storage path by the client;
  // the function reads it, generates, then deletes it. Passing a path (not raw
  // bytes) keeps the request small.
  sourceImagePath: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  // --- 1. Auth -------------------------------------------------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData.user) {
    return json({ error: "unauthorized" }, 401);
  }
  const userId = userData.user.id;

  let body: GenerateRequest;
  try {
    body = await req.json() as GenerateRequest;
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  // --- 2. Rate limit + cost cap -------------------------------------------
  // TODO(phase1): reject if the user is over their per-day generation budget.
  //   Free-tier provider limits are the ceiling; keep caps below them.

  // --- 3. Moderation -------------------------------------------------------
  // TODO(phase1): run image moderation on the source BEFORE generation and
  //   BEFORE deletion (deletion removes our ability to re-review later).

  // --- 4. Generate ---------------------------------------------------------
  // TODO(phase1): call Gemini 2.5 Flash Image with GEMINI_API_KEY
  //   (Deno.env, never shipped to the client) conditioned on the source photo.

  // --- 5. Background removal ----------------------------------------------
  // TODO(phase1): rembg / on-device segmentation -> transparent PNG sprite.

  // --- 6. Persist ----------------------------------------------------------
  // TODO(phase1): upload sprite to storage; insert cats + care_state rows;
  //   set captures.status = 'complete'.

  // --- 7. Delete source photo (ADR 0001) ----------------------------------
  // TODO(phase1): remove body.sourceImagePath from storage regardless of the
  //   generation outcome (except an open moderation case).

  return json(
    {
      status: "not_implemented",
      message: "generate-companion is implemented in Phase 1",
      captureId: body.captureId,
      userId,
    },
    501,
  );
});

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
