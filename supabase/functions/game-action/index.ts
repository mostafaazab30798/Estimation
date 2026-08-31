// Phase 1 W1.1 — Trusted game action entry point (scaffold).
//
// Validates JWT → auth.uid(), room membership, idempotency, and turn legality,
// then delegates to Postgres RPCs. Full reducer logic lands in follow-up PRs.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-action-id",
};

interface GameActionRequest {
  roomId: string;
  action: string;
  payload?: Record<string, unknown>;
  actionId?: string;
  expectedSeq?: number;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return json({ error: "SERVER_MISCONFIGURED" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "NOT_AUTHENTICATED" }, 401);
  }

  let body: GameActionRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  const { roomId, action, payload = {}, actionId, expectedSeq } = body;
  if (!roomId || !action) {
    return json({ error: "MISSING_FIELDS" }, 400);
  }

  if (action.length > 64) {
    return json({ error: "ACTION_TOO_LONG" }, 400);
  }

  const payloadBytes = new TextEncoder().encode(JSON.stringify(payload));
  if (payloadBytes.length > 8192) {
    return json({ error: "PAYLOAD_TOO_LARGE" }, 413);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "NOT_AUTHENTICATED" }, 401);
  }

  const uid = userData.user.id;

  const { data: isMember, error: memberError } = await supabase.rpc(
    "is_room_member",
    { p_room_id: roomId },
  );
  if (memberError || !isMember) {
    return json({ error: "NOT_ROOM_MEMBER" }, 403);
  }

  // TODO(W1.1): apply_game_action RPC — validate turn, bind playerId to uid,
  // enforce idempotent actionId + monotonic expectedSeq, compute next state.
  return json(
    {
      status: "accepted_scaffold",
      roomId,
      action,
      playerId: uid,
      actionId: actionId ?? null,
      expectedSeq: expectedSeq ?? null,
      note: "Reducer not wired yet — host-authoritative path still active in client.",
    },
    202,
  );
});

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
