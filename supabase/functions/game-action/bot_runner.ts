// Runs bot turns on the server after a human action commits — no client host proxy.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  authorityContext,
  loadAuthorityState,
} from "./authority_state.ts";
import { reduceGameAction } from "./reducer/index.ts";
import { planEstimationBotAction } from "./reducer/estimation_bot.ts";
import { planNinetyNineBotAction } from "./reducer/ninety_nine_bot.ts";
import { planBasraBotAction } from "./reducer/basra_bot.ts";
import { sanitizePublicState } from "./reducer/sanitize.ts";
import { GameState } from "./reducer/types.ts";

const MAX_BOT_STEPS = 40;
const BOT_DELAY_MS_MIN = 350;
const BOT_DELAY_MS_MAX = 900;

export interface AuthorityState {
  roomId: string;
  gameType: string;
  hostId: string;
  actionSeq: number;
  maxPlayers: number;
  state: Record<string, unknown>;
}

export async function runServerBotTurns(
  serviceClient: SupabaseClient,
  authority: AuthorityState,
  broadcast: (
    roomId: string,
    state: Record<string, unknown>,
  ) => Promise<void>,
): Promise<number> {
  let seq = authority.actionSeq;
  let current = authority;

  for (let step = 0; step < MAX_BOT_STEPS; step++) {
    const plan = planBotActionForMode(current.gameType, current.state);
    if (!plan) break;

    await delay(BOT_DELAY_MS_MIN + Math.floor(
      Math.random() * (BOT_DELAY_MS_MAX - BOT_DELAY_MS_MIN),
    ));

    const fresh = await loadAuthorityState(serviceClient, current.roomId);
    if (!fresh) break;
    current = {
      roomId: fresh.roomId,
      gameType: fresh.gameType,
      hostId: fresh.hostId,
      actionSeq: fresh.actionSeq,
      maxPlayers: fresh.maxPlayers,
      state: fresh.state,
    };

    const replan = planBotActionForMode(current.gameType, current.state);
    if (!replan || replan.playerId !== plan.playerId || replan.action !== plan.action) {
      continue;
    }

    const payload = { ...replan.payload, playerId: replan.playerId };

    let reduceResult;
    try {
      reduceResult = reduceGameAction({
        ctx: authorityContext(fresh),
        actorUid: replan.playerId,
        action: replan.action,
        payload,
      });
    } catch (error) {
      console.error("[bot_runner] reducer threw:", error);
      break;
    }

    if (!reduceResult.ok || !reduceResult.nextPublicState) break;

    const { data: commit, error } = await serviceClient.rpc("apply_game_action", {
      p_room_id: current.roomId,
      p_actor_uid: current.hostId,
      p_action: replan.action,
      p_payload: payload,
      p_action_id: crypto.randomUUID(),
      p_expected_seq: current.actionSeq,
      p_next_public_state: reduceResult.nextPublicState,
      p_hand_updates: reduceResult.handUpdates ?? {},
    });

    if (error) {
      console.error("[bot_runner] commit failed:", error.message);
      break;
    }

    const commitRow = commit as Record<string, unknown>;
    const publicState = commitRow.publicState as Record<string, unknown> | undefined;
    if (publicState) {
      await broadcast(current.roomId, sanitizePublicState(publicState));
    }

    seq = Number(commitRow.seq ?? current.actionSeq);
    const reloaded = await loadAuthorityState(serviceClient, current.roomId);
    if (!reloaded) break;
    current = {
      roomId: reloaded.roomId,
      gameType: reloaded.gameType,
      hostId: reloaded.hostId,
      actionSeq: reloaded.actionSeq,
      maxPlayers: reloaded.maxPlayers,
      state: reloaded.state,
    };

    if (isTerminalPhase(current.state)) break;
  }

  return seq;
}

function planBotActionForMode(
  gameType: string,
  rawState: Record<string, unknown>,
) {
  if (gameType === "kotchina" || gameType === "estimation") {
    return planEstimationBotAction(rawState as GameState & { botPlayerIds?: string[] });
  }
  if (gameType === "ninety_nine" || gameType === "99") {
    return planNinetyNineBotAction(rawState as Parameters<typeof planNinetyNineBotAction>[0]);
  }
  if (gameType === "basra") {
    return planBasraBotAction(rawState as Parameters<typeof planBasraBotAction>[0]);
  }
  return null;
}

function isTerminalPhase(state: Record<string, unknown>): boolean {
  const phase = String(state.phase ?? "");
  return phase === "matchEnd" || phase === "finished" || phase === "lobby";
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
