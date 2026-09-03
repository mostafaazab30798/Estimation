// Phase 1 W1.1 — Trusted game action authority.
// JWT → membership → TS reducer → apply_game_action RPC (atomic commit).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  authorityContext,
  hydrateLobbyPlayers,
  loadAuthorityState,

  reclaimActingHumanSeat,
} from "./authority_state.ts";
import { reduceGameAction } from "./reducer/index.ts";
import { runServerBotTurns } from "./bot_runner.ts";
import { sanitizePublicState } from "./reducer/sanitize.ts";

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

  // Humans cannot submit moves for bot seats.
  const clientPayload = { ...payload };
  delete clientPayload.playerId;

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
  await hydrateLobbyPlayers(serviceClient, authority);
  reclaimActingHumanSeat(authority, uid);

  let reduceResult;
  try {
    reduceResult = reduceGameAction({
      ctx: authorityContext(authority),
      actorUid: uid,
      action,
      payload: clientPayload,
    });
  } catch (error) {
    console.error("[game-action] reducer threw:", error);
    return json(
      { error: "REDUCER_THROW", detail: String(error) },
      422,
    );
  }

  if (!reduceResult.ok) {
    return json({ error: reduceResult.error ?? "REDUCE_FAILED" }, 422);
  }

  // Ephemeral-only actions (reactions, sync requests) — no state commit.
  if (reduceResult.ephemeral && !reduceResult.nextPublicState) {
    const ephemeral = reduceResult.ephemeral;
    if (ephemeral.type === "sendReaction") {
      await broadcastToRoom(serviceClient, roomId, "reaction", ephemeral);
    } else if (ephemeral.type === "triggerEarthquake") {
      await broadcastToRoom(serviceClient, roomId, "earthquake", ephemeral);
    }
    return json({
      status: "ephemeral",
      seq: authority.actionSeq,
      ephemeral,
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
      p_payload: clientPayload,
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

  const commitRow = commit as Record<string, unknown>;
  const publicState = commitRow.publicState as Record<string, unknown> | undefined;
  if (publicState) {
    await broadcastToRoom(
      serviceClient,
      roomId,
      "state",
      sanitizePublicState(publicState),
    );
  }

  const botRun = await runServerBotTurns(
    serviceClient,
    {
      roomId,
      gameType: authority.gameType,
      hostId: authority.hostId,
      actionSeq: Number(commitRow.seq ?? authority.actionSeq),
      maxPlayers: authority.maxPlayers,
      state: (commitRow.publicState ?? reduceResult.nextPublicState) as Record<
        string,
        unknown
      >,
    },
    (rid, state) => broadcastToRoom(serviceClient, rid, "state", state),
  );

  // Return the caller's hand only over this authenticated HTTP response.
  // Realtime broadcasts and the persisted room snapshot stay sanitized.
  const { data: privateHandRow, error: privateHandError } = await serviceClient
    .from("player_private_hands")
    .select("hand_cards")
    .eq("room_id", roomId)
    .eq("player_id", uid)
    .maybeSingle();
  if (privateHandError) {
    console.error(
      "[game-action] private hand fetch failed:",
      privateHandError.message,
    );
  }

  return json({
    status: "applied",
    ...commitRow,
    // The bot runner may have committed several states after the human action.
    // Returning commitRow.publicState here rolls clients back to the pre-bot
    // snapshot while advancing them to the final sequence number, so the real
    // final room update is then ignored as "already seen".
    seq: botRun.seq,
    publicState: sanitizePublicState(botRun.state),
    privateHand: privateHandRow?.hand_cards ?? [],
    ephemeral: reduceResult.ephemeral ?? null,
  });
});

function mapRpcError(message: string): string {
  if (message.includes("SEQ_MISMATCH")) return "SEQ_MISMATCH";
  if (message.includes("NOT_YOUR_TURN")) return "NOT_YOUR_TURN";
  if (message.includes("WRONG_PHASE")) return "WRONG_PHASE";
  if (message.includes("HOST_ONLY")) return "HOST_ONLY";
  if (message.includes("RATE_LIMIT")) return "RATE_LIMIT_EXCEEDED";
  if (message.includes("NOT_ROOM_MEMBER")) return "NOT_ROOM_MEMBER";
  if (message.includes("UNKNOWN_ACTION")) return "UNKNOWN_ACTION";
  if (message.includes("ACTOR_NOT_IN_GAME")) return "ACTOR_NOT_IN_GAME";

  if (message.includes("TURN_NOT_EXPIRED")) return "TURN_NOT_EXPIRED";
  return "COMMIT_FAILED";
}

function mapRpcStatus(code: string): number {
  switch (code) {
    case "SEQ_MISMATCH":
    case "NOT_YOUR_TURN":
    case "WRONG_PHASE":
    case "HOST_ONLY":
    case "ACTOR_NOT_IN_GAME":

    case "TURN_NOT_EXPIRED":
      return 409;
    case "RATE_LIMIT_EXCEEDED":
      return 429;
    default:
      return 500;
  }
}

async function broadcastToRoom(
  client: ReturnType<typeof createClient>,
  roomId: string,
  event: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const channel = client.channel(`room_${roomId}`);
  await new Promise<void>((resolve) => {
    channel.subscribe(async (status) => {
      if (status === "SUBSCRIBED") {
        await channel.send({ type: "broadcast", event, payload });
        await client.removeChannel(channel);
        resolve();
      } else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") {
        await client.removeChannel(channel);
        resolve();
      }
    });
  });
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
