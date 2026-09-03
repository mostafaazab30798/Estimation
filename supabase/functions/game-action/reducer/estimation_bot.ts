// Server-side Estimation bot planner (no client/host involvement).

import { Card, GameState, Player } from "./types.ts";
import { handContains } from "./types.ts";
import { BotActionPlan, collectBotPlayerIds } from "./bot_common.ts";

const RANK_SORT: Record<string, number> = {
  two: 0,
  three: 1,
  four: 2,
  five: 3,
  six: 4,
  seven: 5,
  eight: 6,
  nine: 7,
  ten: 8,
  jack: 9,
  queen: 10,
  king: 11,
  ace: 12,
};

const TRUMPS = ["club", "diamond", "heart", "spade", "sans"] as const;
const SUITS = ["club", "diamond", "heart", "spade"] as const;
const TRUMP_PRIORITY: Record<string, number> = {
  club: 0,
  diamond: 1,
  heart: 2,
  spade: 3,
  sans: 4,
};

function evaluateContract(hand: Card[], trump: string): number {
  const bySuit = new Map<string, Card[]>();
  for (const suit of SUITS) bySuit.set(suit, []);
  for (const card of hand) bySuit.get(card.suit)?.push(card);

  if (trump === "sans") {
    let total = 0;
    let stoppers = 0;
    for (const suit of SUITS) {
      const cards = bySuit.get(suit) ?? [];
      const len = cards.length;
      if (len === 0) continue;
      const ranks = new Set(cards.map((c) => c.rank));
      const ace = ranks.has("ace");
      const king = ranks.has("king");
      const queen = ranks.has("queen");
      const jack = ranks.has("jack");
      const ten = ranks.has("ten");
      if (ace) {
        total += 1;
        stoppers++;
      }
      if (king) {
        if (ace) total += 0.95;
        else if (queen && len >= 3) {
          total += 0.85;
          stoppers++;
        } else if (len >= 3) {
          total += 0.65;
          stoppers++;
        } else total += len === 2 ? 0.45 : 0.25;
      }
      if (queen) {
        if (ace && king) total += 0.9;
        else if ((ace || king) && len >= 3) total += 0.55;
        else if (len >= 4) total += 0.35;
      }
      if (jack) {
        if (ace && king && queen) total += 0.85;
        else if (ace && king && len >= 4) total += 0.4;
        else if ((ace || king) && len >= 4) total += 0.25;
      }
      if (ten && ace && king && queen && len >= 5) total += 0.4;
      if (ace && king && len >= 5) total += (len - 4) * 0.8;
      else if (ace && len >= 5) total += (len - 4) * 0.6;
    }
    if (stoppers >= 4) total += 0.5;
    return total;
  }

  let total = 0;
  const trumpCards = bySuit.get(trump) ?? [];
  const trumpLen = trumpCards.length;
  for (const card of trumpCards) {
    if (card.rank === "ace") total += 1;
    else if (card.rank === "king") total += trumpLen >= 2 ? 0.95 : 0.65;
    else if (card.rank === "queen") {
      total += trumpLen >= 3 ? 0.85 : trumpLen >= 2 ? 0.55 : 0.3;
    } else if (card.rank === "jack") {
      total += trumpLen >= 4 ? 0.6 : trumpLen >= 3 ? 0.35 : 0.15;
    } else if (card.rank === "ten") {
      total += trumpLen >= 5 ? 0.45 : trumpLen >= 4 ? 0.2 : 0.05;
    }
  }
  if (trumpLen >= 5) total += (trumpLen - 4) * 0.8;
  else if (trumpLen === 4) total += 0.45;

  for (const suit of SUITS) {
    if (suit === trump) continue;
    const cards = bySuit.get(suit) ?? [];
    const len = cards.length;
    const ranks = new Set(cards.map((c) => c.rank));
    const ace = ranks.has("ace");
    const king = ranks.has("king");
    const queen = ranks.has("queen");
    const jack = ranks.has("jack");
    if (len === 0) {
      if (trumpLen >= 4) total += 0.9;
      else if (trumpLen >= 3) total += 0.5;
    } else if (len === 1) {
      if (ace) total += 0.98;
      else if (trumpLen >= 4) total += 0.7;
      else if (trumpLen >= 3) total += 0.35;
    } else if (len === 2) {
      if (ace && king) total += 1.9;
      else if (ace) total += 1;
      else if (king) total += 0.5;
      if (trumpLen >= 4) total += 0.35;
    } else {
      if (ace) total += 0.98;
      if (king) total += ace ? 0.95 : queen ? 0.75 : 0.55;
      if (queen) total += ace && king ? 0.85 : ace || king ? 0.5 : 0.2;
      if (jack && (ace || king) && len >= 4) total += 0.3;
    }
  }
  return total;
}

function shouldCallDash(hand: Card[]): boolean {
  const evaluation = bestContract(hand);
  if (evaluation.expected > 0.75 || hand.some((c) => c.rank === "ace")) {
    return false;
  }
  const highCards =
    hand.filter((c) => (RANK_SORT[c.rank] ?? 0) >= RANK_SORT.jack).length;
  if (highCards > 2) return false;
  for (const suit of SUITS) {
    const cards = hand.filter((c) => c.suit === suit);
    if (cards.length === 0) continue;
    const highest = Math.max(...cards.map((c) => RANK_SORT[c.rank] ?? 0));
    if (highest >= RANK_SORT.queen && cards.length < 3) return false;
  }
  return true;
}

function hasVoidSuit(hand: Card[]): boolean {
  return SUITS.some((suit) => !hand.some((card) => card.suit === suit));
}

function shouldApproveRedeal(hand: Card[]): boolean {
  return bestContract(hand).expected < 3.5;
}

function bestContract(hand: Card[]): { trump: string; expected: number } {
  return TRUMPS
    .map((trump) => ({ trump, expected: evaluateContract(hand, trump) }))
    .sort((a, b) => b.expected - a.expected)[0];
}

function isValidBid(
  trickCount: number,
  trump: string,
  current: { trickCount: number; trump: string } | null | undefined,
): boolean {
  if (trickCount < 4 || trickCount > 13) return false;
  if (!current) return true;
  return trickCount > current.trickCount ||
    (trickCount === current.trickCount &&
      (TRUMP_PRIORITY[trump] ?? -1) > (TRUMP_PRIORITY[current.trump] ?? -1));
}

function fixedTrumpForState(state: GameState): string | null {
  if (state.totalRounds !== 18 && state.totalRounds !== 10) return null;
  const firstFixedRound = state.totalRounds - 4;
  if (
    state.roundNumber < firstFixedRound || state.roundNumber > state.totalRounds
  ) {
    return null;
  }
  return ["sans", "spade", "heart", "diamond", "club"][
    state.roundNumber - firstFixedRound
  ] ?? null;
}

function decideAuctionBid(state: GameState, bot: Player) {
  if (bot.isDashCall) return null;
  const fixedTrump = fixedTrumpForState(state);
  if (fixedTrump) {
    const fixedExpected = evaluateContract(bot.hand, fixedTrump);
    const maxSafe = Math.max(4, Math.min(13, Math.floor(fixedExpected)));
    if (fixedExpected >= 3.8) {
      for (let tricks = 4; tricks <= maxSafe; tricks++) {
        if (isValidBid(tricks, fixedTrump, state.currentHighBid)) {
          return { trickCount: tricks, trump: fixedTrump };
        }
      }
    }
    for (const trump of TRUMPS) {
      if (trump === fixedTrump) continue;
      const expected = evaluateContract(bot.hand, trump);
      if (expected < 7.8) continue;
      const tricks = Math.max(8, Math.min(13, Math.floor(expected)));
      if (isValidBid(tricks, trump, state.currentHighBid)) {
        return { trickCount: tricks, trump };
      }
    }
    return null;
  }
  const candidates = TRUMPS
    .map((trump) => ({ trump, expected: evaluateContract(bot.hand, trump) }))
    .filter(({ trump, expected }) => {
      if (trump === "sans") return expected >= 4.2;
      const length = bot.hand.filter((c) => c.suit === trump).length;
      return length >= 4 && expected >= 3.8;
    })
    .sort((a, b) => b.expected - a.expected);

  for (const candidate of candidates) {
    const maxSafe = Math.max(4, Math.min(13, Math.floor(candidate.expected)));
    for (let tricks = 4; tricks <= maxSafe; tricks++) {
      if (isValidBid(tricks, candidate.trump, state.currentHighBid)) {
        return { trickCount: tricks, trump: candidate.trump };
      }
    }
  }
  return null;
}

function decideDeclaration(state: GameState, bot: Player): number {
  if (bot.isDashCall) return 0;
  const expected = evaluateContract(bot.hand, state.trump ?? "sans");
  const isBidder = state.bidderPlayerId === bot.id;
  const minimum = isBidder ? state.currentHighBid?.trickCount ?? 0 : 0;
  let declaration = Math.max(minimum, Math.min(13, Math.round(expected)));

  if (!isBidder && state.bidderPlayerId) {
    const bidder = state.players.find((p) => p.id === state.bidderPlayerId);
    if (bidder?.declared != null) {
      declaration = Math.min(declaration, bidder.declared);
    }
  }

  const declared = state.players.filter((p) => p.declared != null);
  if (declared.length === state.players.length - 1) {
    const forbidden = 13 -
      declared.reduce((sum, p) => sum + (p.declared ?? 0), 0);
    if (declaration === forbidden) {
      declaration = declaration > minimum
        ? declaration - 1
        : Math.min(13, declaration + 1);
    }
  }
  return declaration;
}

function canPlayCard(state: GameState, player: Player, card: Card): boolean {
  if (state.currentPlayerSeatIndex !== player.seatIndex) return false;
  if (!handContains(player.hand, card)) return false;
  if (state.currentTrick.length === 0) return true;
  const ledSuit = state.currentTrick[0].card.suit;
  const hasLed = player.hand.some((c) => c.suit === ledSuit);
  if (hasLed && card.suit !== ledSuit) return false;
  return true;
}

type CardMemory = {
  played: Set<string>;
  remainingTrumps: number;
};

function cardId(card: Card): string {
  return `${card.suit}_${card.rank}`;
}

function buildCardMemory(state: GameState): CardMemory {
  const played = new Set<string>();
  for (const player of state.players) {
    for (const trick of player.takenTricks ?? []) {
      for (const trickCard of trick) played.add(cardId(trickCard.card));
    }
  }
  for (const trickCard of state.currentTrick) {
    played.add(cardId(trickCard.card));
  }

  let remainingTrumps = 0;
  if (state.trump && state.trump !== "sans") {
    for (const rank of Object.keys(RANK_SORT)) {
      if (!played.has(`${state.trump}_${rank}`)) remainingTrumps++;
    }
  }
  return { played, remainingTrumps };
}

function isMaster(card: Card, memory: CardMemory): boolean {
  const rank = RANK_SORT[card.rank] ?? 0;
  for (const [higherRank, value] of Object.entries(RANK_SORT)) {
    if (value > rank && !memory.played.has(`${card.suit}_${higherRank}`)) {
      return false;
    }
  }
  return true;
}

function currentWinner(state: GameState): Card {
  const ledSuit = state.currentTrick[0].card.suit;
  const trump = state.trump;
  const pool = trump && trump !== "sans"
    ? state.currentTrick.filter((tc) => tc.card.suit === trump)
    : [];
  const contenders = pool.length > 0
    ? pool
    : state.currentTrick.filter((tc) => tc.card.suit === ledSuit);
  return [...contenders].sort(
    (a, b) => (RANK_SORT[b.card.rank] ?? 0) - (RANK_SORT[a.card.rank] ?? 0),
  )[0].card;
}

function rankAscending(cards: Card[]): Card[] {
  return [...cards].sort(
    (a, b) => (RANK_SORT[a.rank] ?? 0) - (RANK_SORT[b.rank] ?? 0),
  );
}

function rankDescending(cards: Card[]): Card[] {
  return [...cards].sort(
    (a, b) => (RANK_SORT[b.rank] ?? 0) - (RANK_SORT[a.rank] ?? 0),
  );
}

function longestSuitCard(
  cards: Card[],
  allowedSuits: readonly string[],
  highest: boolean,
): Card | null {
  let bestSuit: string | null = null;
  let bestLength = 0;
  for (const suit of allowedSuits) {
    const length = cards.filter((c) => c.suit === suit).length;
    if (length > bestLength) {
      bestLength = length;
      bestSuit = suit;
    }
  }
  if (!bestSuit) return null;
  const suited = cards.filter((c) => c.suit === bestSuit);
  return (highest ? rankDescending(suited) : rankAscending(suited))[0] ?? null;
}

function chooseLeadCard(
  state: GameState,
  legal: Card[],
  wantToWin: boolean,
  memory: CardMemory,
): Card {
  const trump = state.trump;
  const isSans = !trump || trump === "sans";
  if (wantToWin) {
    if (!isSans) {
      const trumps = legal.filter((c) => c.suit === trump);
      if (trumps.length > 0 && memory.remainingTrumps > trumps.length) {
        const masters = rankDescending(
          trumps.filter((c) => isMaster(c, memory)),
        );
        if (masters.length > 0) return masters[0];
      }
    }
    const sideMasters = rankDescending(
      legal.filter((c) => (isSans || c.suit !== trump) && isMaster(c, memory)),
    );
    if (sideMasters.length > 0) return sideMasters[0];
    const suits = isSans ? SUITS : SUITS.filter((s) => s !== trump);
    return longestSuitCard(legal, suits, true) ?? rankDescending(legal)[0];
  }

  const nonMasters = legal.filter((c) => !isMaster(c, memory));
  const pool = nonMasters.length > 0 ? nonMasters : legal;
  const suits = isSans ? SUITS : SUITS.filter((s) => s !== trump);
  return longestSuitCard(pool, suits, false) ?? rankAscending(pool)[0];
}

function chooseFollowCard(
  state: GameState,
  legal: Card[],
  wantToWin: boolean,
  memory: CardMemory,
): Card {
  const ledSuit = state.currentTrick[0].card.suit;
  const winner = currentWinner(state);
  const trump = state.trump;
  const isSans = !trump || trump === "sans";
  const isLast = state.currentTrick.length === state.players.length - 1;
  const ledCards = legal.filter((c) => c.suit === ledSuit);

  if (ledCards.length > 0) {
    if (wantToWin) {
      if (!isSans && winner.suit === trump && ledSuit !== trump) {
        return rankAscending(ledCards)[0];
      }
      const winners = rankAscending(
        ledCards.filter((c) =>
          (RANK_SORT[c.rank] ?? 0) > (RANK_SORT[winner.rank] ?? 0)
        ),
      );
      if (winners.length > 0) {
        return isLast || winners.length === 1
          ? winners[0]
          : winners[winners.length - 1];
      }
      return rankAscending(ledCards)[0];
    }
    if (!isSans && winner.suit === trump && ledSuit !== trump) {
      return rankDescending(ledCards)[0];
    }
    const safe = rankDescending(
      ledCards.filter((c) =>
        (RANK_SORT[c.rank] ?? 0) < (RANK_SORT[winner.rank] ?? 0)
      ),
    );
    return safe[0] ?? rankAscending(ledCards)[0];
  }

  if (isSans) {
    if (wantToWin) return rankAscending(legal)[0];
    const dangerous = rankDescending(
      legal.filter((c) =>
        (RANK_SORT[c.rank] ?? 0) >= RANK_SORT.jack && !isMaster(c, memory)
      ),
    );
    return dangerous[0] ?? rankAscending(legal)[0];
  }

  const trumps = legal.filter((c) => c.suit === trump);
  const nonTrumps = legal.filter((c) => c.suit !== trump);
  if (wantToWin) {
    if (trumps.length > 0) {
      if (winner.suit === trump) {
        const overtrumps = rankAscending(
          trumps.filter((c) =>
            (RANK_SORT[c.rank] ?? 0) > (RANK_SORT[winner.rank] ?? 0)
          ),
        );
        if (overtrumps.length > 0) {
          return isLast ? overtrumps[0] : overtrumps[overtrumps.length - 1];
        }
      } else {
        return rankAscending(trumps)[0];
      }
    }
    return nonTrumps.length > 0
      ? rankAscending(nonTrumps)[0]
      : rankAscending(trumps)[0];
  }

  if (nonTrumps.length > 0) {
    const dangerous = rankDescending(
      nonTrumps.filter((c) => (RANK_SORT[c.rank] ?? 0) >= RANK_SORT.jack),
    );
    return dangerous[0] ?? rankDescending(nonTrumps)[0];
  }
  return rankAscending(trumps)[0];
}

function pickCard(state: GameState, bot: Player): Card | null {
  const legal = bot.hand.filter((c) => canPlayCard(state, bot, c));
  if (legal.length === 0) return bot.hand[0] ?? null;
  if (legal.length === 1) return legal[0];
  const needed = (bot.declared ?? 0) - bot.actual;
  const tricksLeft = 13 - state.tricksPlayedThisRound;
  const wantToWin = needed > 0 && needed <= tricksLeft;
  const memory = buildCardMemory(state);
  return state.currentTrick.length === 0
    ? chooseLeadCard(state, legal, wantToWin, memory)
    : chooseFollowCard(state, legal, wantToWin, memory);
}

function activeBotForTurn(
  state: GameState,
  botIds: Set<string>,
): Player | null {
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
        const approve = bot.id === state.voidDeclaringPlayerId ||
          hasVoidSuit(bot.hand) || shouldApproveRedeal(bot.hand);
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
        payload: { wantsDashCall: shouldCallDash(bot.hand) },
      };

    case "auction": {
      const bid = decideAuctionBid(state, bot);
      return bid
        ? { action: "submitBid", playerId: bot.id, payload: { bid } }
        : { action: "passBid", playerId: bot.id, payload: {} };
    }

    case "declarations": {
      const declared = decideDeclaration(state, bot);
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
