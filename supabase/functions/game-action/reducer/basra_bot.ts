// Server-side Basra bot planner (no client/host involvement).

import {
  basraNumericValue,
  cardId,
  isJack,
  isSevenOfDiamonds,
  isTenOfDiamonds,
  isTwoOfSpades,
} from "./cards.ts";
import { previewBasraPlay } from "./basra.ts";
import { Card } from "./types.ts";
import { BotActionPlan, collectBotPlayerIds } from "./bot_common.ts";

interface BasraPlayer {
  id: string;
  hand: Card[];
  isBot?: boolean;
}

interface BasraState {
  phase: string;
  currentPlayerIndex: number;
  tableCards: Card[];
  players: BasraPlayer[];
  botPlayerIds?: string[];
}

function scoreCandidate(
  card: Card,
  tableCards: Card[],
  resolved: ReturnType<typeof previewBasraPlay>,
): number {
  if (!resolved.wasCapture) {
    let dump = 40 - (basraNumericValue(card) ?? 12);
    if (isJack(card) || isSevenOfDiamonds(card)) dump -= 80;
    if (isTenOfDiamonds(card) || isTwoOfSpades(card)) dump -= 30;
    if (tableCards.length === 0 && (isJack(card) || isSevenOfDiamonds(card))) {
      dump -= 40;
    }
    return dump;
  }

  let score = 100 + resolved.captured.length * 12;
  if (resolved.basraType !== "none") score += 200;
  for (const captured of resolved.captured) {
    if (isJack(captured)) score += 18;
    if (captured.rank === "ace") score += 18;
    if (isTwoOfSpades(captured)) score += 28;
    if (isTenOfDiamonds(captured)) score += 36;
  }
  if (isJack(card)) score += 8;
  if (isSevenOfDiamonds(card)) score += 10;
  return score;
}

function chooseCard(hand: Card[], tableCards: Card[]): Card | null {
  if (hand.length === 0) return null;
  if (hand.length === 1) return hand[0];

  let best: Card | null = null;
  let bestScore = -0x7fffffff;

  for (const card of hand) {
    const resolved = previewBasraPlay(card, tableCards);
    const score = scoreCandidate(card, tableCards, resolved);
    if (
      score > bestScore ||
      (score === bestScore && best != null && cardId(card) < cardId(best)) ||
      best == null
    ) {
      bestScore = score;
      best = card;
    }
  }

  return best;
}

/** Returns the next bot move, or null if a human should act. */
export function planBasraBotAction(state: BasraState): BotActionPlan | null {
  if (state.phase !== "playing") return null;

  const botIds = collectBotPlayerIds(state);
  if (botIds.size === 0) return null;

  const cur = state.players[state.currentPlayerIndex];
  if (!cur || !botIds.has(cur.id)) return null;

  const card = chooseCard(cur.hand, state.tableCards);
  if (!card) return null;

  return {
    action: "playCardBasra",
    playerId: cur.id,
    payload: { card },
  };
}
