import { planEstimationBotAction } from "./estimation_bot.ts";
import { Card, GameState, Player } from "./types.ts";

function card(suit: string, rank: string): Card {
  return { suit, rank };
}

function player(id: string, seatIndex: number, hand: Card[]): Player {
  return {
    id,
    name: id,
    seatIndex,
    hand,
    takenTricks: [],
    declared: 1,
    actual: 0,
    hasPassed: false,
    isDashCall: false,
    isRisk: false,
    totalScore: 0,
    isBot: id === "bot_0",
  };
}

function trickState(botHand: Card[]): GameState {
  return {
    players: [
      player("human_0", 0, []),
      player("human_1", 1, []),
      player("human_2", 2, []),
      player("bot_0", 3, botHand),
    ],
    phase: "trickTaking",
    roundNumber: 1,
    totalRounds: 18,
    dealerSeatIndex: 0,
    isDoubleRound: false,
    dashCallPassed: [],
    currentHighBid: { trickCount: 4, trump: "spade" },
    currentHighBidderPlayerId: "bot_0",
    auctionTurnSeatIndex: 3,
    bidderPlayerId: "bot_0",
    trump: "spade",
    currentTrick: [
      { playerId: "human_0", card: card("heart", "ten") },
      { playerId: "human_1", card: card("heart", "three") },
      { playerId: "human_2", card: card("heart", "eight") },
    ],
    trickLeaderSeatIndex: 0,
    tricksPlayedThisRound: 2,
    currentPlayerSeatIndex: 3,
    lastRoundScoreDeltas: {},
    roundHistory: [],
    voidCheckPassed: [],
    voidRedealRejections: [],
    turnDurationSeconds: 60,
    cardTheme: "theme_1",
    botPlayerIds: ["bot_0"],
  };
}

function assertCard(actual: unknown, expected: Card): void {
  const value = actual as Card;
  if (value?.suit !== expected.suit || value?.rank !== expected.rank) {
    throw new Error(
      `expected ${expected.suit}_${expected.rank}, got ${
        JSON.stringify(actual)
      }`,
    );
  }
}

Deno.test("online bot wins last seat with cheapest sufficient card", () => {
  const state = trickState([card("heart", "jack"), card("heart", "ace")]);
  const plan = planEstimationBotAction(state);
  assertCard(plan?.payload.card, card("heart", "jack"));
});

Deno.test("online bot ducks under winner after reaching declaration", () => {
  const state = trickState([card("heart", "nine"), card("heart", "king")]);
  state.players[3].actual = 1;
  const plan = planEstimationBotAction(state);
  assertCard(plan?.payload.card, card("heart", "nine"));
});

Deno.test("online bot ruffs with its lowest trump when it needs tricks", () => {
  const state = trickState([card("spade", "four"), card("spade", "queen")]);
  const plan = planEstimationBotAction(state);
  assertCard(plan?.payload.card, card("spade", "four"));
});

Deno.test("online bot bids a strong contract instead of blindly passing", () => {
  const state = trickState([
    card("spade", "ace"),
    card("spade", "king"),
    card("spade", "queen"),
    card("spade", "jack"),
    card("spade", "ten"),
    card("heart", "ace"),
    card("diamond", "ace"),
    card("club", "ace"),
  ]);
  state.phase = "auction";
  state.auctionTurnSeatIndex = 3;
  state.currentHighBid = null;
  const plan = planEstimationBotAction(state);
  if (plan?.action !== "submitBid") {
    throw new Error(`expected a bid, got ${JSON.stringify(plan)}`);
  }
});
