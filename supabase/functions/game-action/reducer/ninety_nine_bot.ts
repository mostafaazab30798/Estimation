// Server-side 99 bot planner (no client/host involvement).

import { applyEffect99, isLegalPlay99, isSafeCard99 } from "./cards.ts";
import { Card } from "./types.ts";
import { BotActionPlan, collectBotPlayerIds } from "./bot_common.ts";

interface NinetyNinePlayer {
  id: string;
  hand: Card[];
  isBot?: boolean;
}

interface NinetyNineState {
  phase: string;
  groundTotal: number;
  currentPlayerIndex: number;
  players: NinetyNinePlayer[];
  botPlayerIds?: string[];
}

function chooseCard(hand: Card[], groundTotal: number): Card | null {
  if (hand.length === 0) return null;

  const legal = hand.filter((c) => isLegalPlay99(groundTotal, c));
  if (legal.length === 0) return hand[0];
  if (legal.length === 1) return legal[0];

  if (groundTotal === 99) {
    const jack = legal.find((c) => c.rank === "jack");
    if (jack) return jack;
    const seven = legal.find((c) => c.rank === "seven");
    if (seven) return seven;
    const four = legal.find((c) => c.rank === "four");
    if (four) return four;
    return legal[0];
  }

  const normal = legal.filter((c) => !isSafeCard99(c));
  if (normal.length > 0) {
    const sorted = [...normal].sort(
      (a, b) => applyEffect99(groundTotal, b) - applyEffect99(groundTotal, a),
    );
    return sorted[0];
  }

  const four = legal.find((c) => c.rank === "four");
  if (four) return four;
  const king = legal.find((c) => c.rank === "king");
  if (king) return king;
  const seven = legal.find((c) => c.rank === "seven");
  if (seven) return seven;
  return legal[0];
}

/** Returns the next bot move, or null if a human should act. */
export function planNinetyNineBotAction(state: NinetyNineState): BotActionPlan | null {
  if (state.phase !== "playing") return null;

  const botIds = collectBotPlayerIds(state);
  if (botIds.size === 0) return null;

  const cur = state.players[state.currentPlayerIndex];
  if (!cur || !botIds.has(cur.id)) return null;

  const card = chooseCard(cur.hand, state.groundTotal);
  if (!card) return null;

  return {
    action: "playCardNinetyNine",
    playerId: cur.id,
    payload: { card },
  };
}
