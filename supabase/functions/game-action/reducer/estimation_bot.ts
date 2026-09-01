// Server-side Estimation bot planner (no client/host involvement).

import { Card, GameState, Player } from "./types.ts";
import { handContains } from "./types.ts";
import { BotActionPlan, collectBotPlayerIds } from "./bot_common.ts";

const RANK_SORT: Record<string, number> = {
  two: 0, three: 1, four: 2, five: 3, six: 4, seven: 5, eight: 6,
  nine: 7, ten: 8, jack: 9, queen: 10, king: 11, ace: 12,
};

function canPlayCard(state: GameState, player: Player, card: Card): boolean {
  if (state.currentPlayerSeatIndex !== player.seatIndex) return false;
  if (!handContains(player.hand, card)) return false;
  if (state.currentTrick.length === 0) return true;
  const ledSuit = state.currentTrick[0].card.suit;
  const hasLed = player.hand.some((c) => c.suit === ledSuit);
  if (hasLed && card.suit !== ledSuit) return false;
  return true;
}

function pickCard(state: GameState, bot: Player): Card | null {
  const legal = bot.hand.filter((c) => canPlayCard(state, bot, c));
  if (legal.length === 0) return bot.hand[0] ?? null;
  legal.sort((a, b) => (RANK_SORT[a.rank] ?? 0) - (RANK_SORT[b.rank] ?? 0));
  return legal[0];
}

function activeBotForTurn(state: GameState, botIds: Set<string>): Player | null {
  switch (state.phase) {
    case "voidCheck": {
      if (state.voidDeclaringPlayerId) {
        for (const id of botIds) {
          if (!state.voidRedealRejections.includes(id)) {
            const bot = state.players.find((p) => p.id === id);
            if (bot) return bot;
          }
        }
        return null;
      }
      for (const id of botIds) {
        if (!state.voidCheckPassed.includes(id)) {
          const bot = state.players.find((p) => p.id === id);
          if (bot) return bot;
        }
      }
      return null;
    }
    case "dashCall": {
      const bot = state.players.find(
        (p) => p.seatIndex === state.currentPlayerSeatIndex,
      );
      return bot && botIds.has(bot.id) ? bot : null;
    }
    case "auction": {
      const bot = state.players.find(
        (p) => p.seatIndex === state.auctionTurnSeatIndex,
      );
      return bot && botIds.has(bot.id) ? bot : null;
    }
    case "declarations": {
      const bot = state.players.find(
        (p) => p.seatIndex === state.currentPlayerSeatIndex,
      );
      return bot && botIds.has(bot.id) ? bot : null;
    }
    case "trickTaking": {
      if (state.currentTrick.length >= state.players.length) return null;
      const bot = state.players.find(
        (p) => p.seatIndex === state.currentPlayerSeatIndex,
      );
      return bot && botIds.has(bot.id) ? bot : null;
    }
    default:
      return null;
  }
}

/** Returns the next bot move, or null if a human should act. */
export function planEstimationBotAction(
  state: GameState & { botPlayerIds?: string[] },
): BotActionPlan | null {
  const botIds = collectBotPlayerIds(state);
  if (botIds.size === 0) return null;

  const bot = activeBotForTurn(state, botIds);
  if (!bot) return null;

  switch (state.phase) {
    case "voidCheck":
      if (state.voidDeclaringPlayerId) {
        const approve = bot.id === state.voidDeclaringPlayerId;
        return {
          action: approve ? "approveRedeal" : "rejectRedeal",
          playerId: bot.id,
          payload: {},
        };
      }
      return { action: "confirmNoVoid", playerId: bot.id, payload: {} };

    case "dashCall":
      return {
        action: "submitDashCall",
        playerId: bot.id,
        payload: { wantsDashCall: false },
      };

    case "auction":
      return { action: "passBid", playerId: bot.id, payload: {} };

    case "declarations": {
      const declared = Math.min(bot.hand.length, 3);
      return {
        action: "submitDeclaration",
        playerId: bot.id,
        payload: { declared },
      };
    }

    case "trickTaking": {
      const card = pickCard(state, bot);
      if (!card) return null;
      return {
        action: "playCard",
        playerId: bot.id,
        payload: { card },
      };
    }

    default:
      return null;
  }
}
