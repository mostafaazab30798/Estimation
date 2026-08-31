// Phase 1 W1.1 — Trusted game action authority.
// JWT → membership → TS reducer → apply_game_action RPC (atomic commit).

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { reduceGameAction } from "./reducer/index.ts";

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
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
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

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "NOT_AUTHENTICATED" }, 401);
  }

  const uid = userData.user.id;

  const { data: isMember, error: memberError } = await userClient.rpc(
    "is_room_member",
    { p_room_id: roomId },
  );
  if (memberError || !isMember) {
    return json({ error: "NOT_ROOM_MEMBER" }, 403);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  const authority = await loadAuthorityState(serviceClient, roomId);
  if (!authority) {
    return json({ error: "ROOM_NOT_FOUND" }, 404);
  }

  const reduceResult = reduceGameAction({
    ctx: authority,
    actorUid: uid,
    action,
    payload,
  });

  if (!reduceResult.ok) {
    return json({ error: reduceResult.error ?? "REDUCE_FAILED" }, 422);
  }

  // Ephemeral-only actions (reactions, sync requests) — no state commit.
  if (reduceResult.ephemeral && !reduceResult.nextPublicState) {
    return json({
      status: "ephemeral",
      seq: authority.actionSeq,
      ephemeral: reduceResult.ephemeral,
    });
  }

  if (!reduceResult.nextPublicState) {
    return json({ error: "NO_STATE" }, 500);
  }

  const resolvedActionId = actionId ?? crypto.randomUUID();

  const { data: commit, error: commitError } = await serviceClient.rpc(
    "apply_game_action",
    {
      p_room_id: roomId,
      p_actor_uid: uid,
      p_action: action,
      p_payload: payload,
      p_action_id: resolvedActionId,
      p_expected_seq: expectedSeq ?? authority.actionSeq,
      p_next_public_state: reduceResult.nextPublicState,
      p_hand_updates: reduceResult.handUpdates ?? {},
    },
  );

  if (commitError) {
    const code = mapRpcError(commitError.message);
    return json({ error: code, detail: commitError.message }, mapRpcStatus(code));
  }

  return json({
    status: "applied",
    ...(commit as Record<string, unknown>),
    ephemeral: reduceResult.ephemeral ?? null,
  });
});

async function loadAuthorityState(
  client: SupabaseClient,
  roomId: string,
): Promise<{
  roomId: string;
  gameType: string;
  hostId: string;
  actionSeq: number;
  state: Record<string, unknown>;
} | null> {
  const { data, error } = await client.rpc("get_authority_room_state", {
    p_room_id: roomId,
  });

  if (error || !data) return null;

  const row = data as Record<string, unknown>;
  return {
    roomId: String(row.roomId),
    gameType: String(row.gameType ?? "kotchina"),
    hostId: String(row.hostId),
    actionSeq: Number(row.actionSeq ?? 0),
    state: (row.state ?? {}) as Record<string, unknown>,
  };
}

function mapRpcError(message: string): string {
  if (message.includes("SEQ_MISMATCH")) return "SEQ_MISMATCH";
  if (message.includes("NOT_YOUR_TURN")) return "NOT_YOUR_TURN";
  if (message.includes("WRONG_PHASE")) return "WRONG_PHASE";
  if (message.includes("HOST_ONLY")) return "HOST_ONLY";
  if (message.includes("RATE_LIMIT")) return "RATE_LIMIT_EXCEEDED";
  if (message.includes("NOT_ROOM_MEMBER")) return "NOT_ROOM_MEMBER";
  if (message.includes("UNKNOWN_ACTION")) return "UNKNOWN_ACTION";
  return "COMMIT_FAILED";
}

function mapRpcStatus(code: string): number {
  switch (code) {
    case "SEQ_MISMATCH":
    case "NOT_YOUR_TURN":
    case "WRONG_PHASE":
    case "HOST_ONLY":
      return 409;
    case "RATE_LIMIT_EXCEEDED":
      return 429;
    default:
      return 500;
  }
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
