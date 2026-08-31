// Estimation (kotchina) authoritative reducer — mirrors lib/core/game_engine.dart.

import {
  Bid,
  Card,
  GameState,
  Player,
  ReduceInput,
  ReduceResult,
  TrickCard,
  cloneState,
  errResult,
  handContains,
  handUpdatesFromState,
  okResult,
  playerById,
  playerBySeat,
  removeCard,
} from "./types.ts";

const K_BOUla_TOTAL_ROUNDS = 18;
const K_MIN_BID_TRICKS = 4;
const K_OVERRIDE_FIXED_TRUMP_TRICKS = 8;
const K_TRICKS_PER_ROUND = 13;
const K_FIXED_TRUMP_ROUND_COUNT = 5;
const K_MATCH_END_SCORE = 50;
const MAX_PLAYERS = 4;

const SUITS = ["club", "diamond", "heart", "spade"] as const;
const RANKS = [
  "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "jack", "queen", "king", "ace",
] as const;

const TRUMP_PRIORITY: Record<string, number> = {
  club: 0, diamond: 1, heart: 2, spade: 3, sans: 4,
};

const SUIT_PRIORITY: Record<string, number> = {
  club: 0, diamond: 1, heart: 2, spade: 3,
};

const RANK_SORT: Record<string, number> = Object.fromEntries(
  RANKS.map((r, i) => [r, i]),
);

function isRoundBasedBoula(totalRounds: number): boolean {
  return totalRounds === 18 || totalRounds === 10;
}

function fixedTrumpForRound(roundNumber: number, totalRounds: number): string | null {
  if (!isRoundBasedBoula(totalRounds)) return null;
  const firstFixed = totalRounds - K_FIXED_TRUMP_ROUND_COUNT + 1;
  if (roundNumber < firstFixed || roundNumber > totalRounds) return null;
  const order = ["sans", "spade", "heart", "diamond", "club"];
  return order[roundNumber - firstFixed] ?? null;
}

function getFixedTrump(state: GameState): string | null {
  return fixedTrumpForRound(state.roundNumber, state.totalRounds);
}

function fullDeck(): Card[] {
  const deck: Card[] = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({ suit, rank });
    }
  }
  return deck;
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function autoSort(hand: Card[]): void {
  hand.sort((a, b) => {
    const suitOrder = 3 - (SUIT_PRIORITY[a.suit] ?? 0);
    const rankOrder = 12 - (RANK_SORT[a.rank] ?? 0);
    return suitOrder * 100 + rankOrder;
  });
}

function dealCards(state: GameState): void {
  const deck = shuffle(fullDeck());
  for (const p of state.players) p.hand = [];
  for (let i = 0; i < deck.length; i++) {
    const seat = i % state.players.length;
    playerBySeat(state, seat).hand.push(deck[i]);
  }
  for (const p of state.players) autoSort(p.hand);
}

function hasVoidSuit(player: Player): boolean {
  const suits = new Set(player.hand.map((c) => c.suit));
  return suits.size < SUITS.length;
}

function findVoidSuitPlayer(state: GameState): Player | null {
  const ordered = [...state.players].sort((a, b) => a.seatIndex - b.seatIndex);
  return ordered.find((p) => hasVoidSuit(p)) ?? null;
}

function proceedAfterVoidCheck(state: GameState): void {
  state.voidDeclaringPlayerId = null;
  state.voidRedealRejections = [];
  state.voidCheckPassed = [];
  const firstSeat = (state.dealerSeatIndex + 1) % state.players.length;
  const fixed = getFixedTrump(state);
  if (fixed) {
    state.trump = fixed;
    state.phase = "declarations";
    state.currentPlayerSeatIndex = firstSeat;
  } else {
    state.dashCallPassed = [];
    state.phase = "dashCall";
    state.currentPlayerSeatIndex = firstSeat;
  }
}

function enterPostDealPhase(state: GameState): void {
  state.voidCheckPassed = [];
  state.voidRedealRejections = [];
  const voidPlayer = findVoidSuitPlayer(state);
  if (voidPlayer) {
    state.phase = "voidCheck";
    state.voidDeclaringPlayerId = voidPlayer.id;
    return;
  }
  state.voidDeclaringPlayerId = null;
  proceedAfterVoidCheck(state);
}

function passVoidCheck(state: GameState, playerId: string): void {
  if (!state.voidCheckPassed.includes(playerId)) {
    state.voidCheckPassed.push(playerId);
  }
  if (state.voidCheckPassed.length === state.players.length) {
    proceedAfterVoidCheck(state);
  }
}

function submitDashCall(state: GameState, playerId: string, wantsDashCall: boolean): void {
  const player = playerById(state, playerId);
  if (player.seatIndex !== state.currentPlayerSeatIndex) return;

  if (!state.dashCallPassed.includes(playerId)) {
    state.dashCallPassed.push(playerId);
  }
  if (wantsDashCall) {
    player.isDashCall = true;
    player.declared = 0;
    player.hasPassed = true;
  }

  if (state.dashCallPassed.length === state.players.length) {
    const fixed = getFixedTrump(state);
    if (fixed) {
      state.trump = fixed;
      state.currentPlayerSeatIndex = (state.dealerSeatIndex + 1) % state.players.length;
      state.phase = "declarations";
    } else {
      state.auctionTurnSeatIndex = (state.dealerSeatIndex + 1) % state.players.length;
      state.phase = "auction";
      checkAuctionState(state);
    }
  } else {
    state.currentPlayerSeatIndex = (state.currentPlayerSeatIndex + 1) % state.players.length;
  }
}

function isValidBid(bid: Bid, currentHighBid: Bid | null | undefined, state: GameState): boolean {
  if (bid.trickCount < K_MIN_BID_TRICKS) return false;
  const fixed = getFixedTrump(state);
  if (fixed && bid.trump !== fixed && bid.trickCount < K_OVERRIDE_FIXED_TRUMP_TRICKS) {
    return false;
  }
  if (!currentHighBid) return true;
  if (bid.trickCount > currentHighBid.trickCount) return true;
  if (bid.trickCount === currentHighBid.trickCount) {
    return (TRUMP_PRIORITY[bid.trump] ?? 0) > (TRUMP_PRIORITY[currentHighBid.trump] ?? 0);
  }
  return false;
}

function getNextSeat(state: GameState, currentSeat: number, isValid: (p: Player) => boolean): number {
  let next = (currentSeat + 1) % state.players.length;
  while (next !== currentSeat) {
    if (isValid(playerBySeat(state, next))) return next;
    next = (next + 1) % state.players.length;
  }
  return currentSeat;
}

function finaliseAuction(state: GameState): void {
  const bidder = playerById(state, state.currentHighBidderPlayerId!);
  state.bidderPlayerId = bidder.id;
  const fixed = getFixedTrump(state);
  if (
    fixed &&
    state.currentHighBid &&
    (state.currentHighBid.trickCount < K_OVERRIDE_FIXED_TRUMP_TRICKS ||
      state.currentHighBid.trump === fixed)
  ) {
    state.trump = fixed;
  } else if (state.currentHighBid) {
    state.trump = state.currentHighBid.trump;
  }
  state.trickLeaderSeatIndex = bidder.seatIndex;
  state.currentPlayerSeatIndex = bidder.seatIndex;
  state.phase = "declarations";
}

function handleAllPass(state: GameState): void {
  state.isDoubleRound = true;
  startNextRound(state);
}

function advanceAuctionTurn(state: GameState): void {
  const active = state.players.filter((p) => !p.hasPassed);
  if (
    active.length === 1 &&
    state.currentHighBidderPlayerId &&
    active[0].id === state.currentHighBidderPlayerId
  ) {
    finaliseAuction(state);
    return;
  }
  if (active.length === 0) {
    handleAllPass(state);
    return;
  }
  state.auctionTurnSeatIndex = getNextSeat(
    state,
    state.auctionTurnSeatIndex,
    (p) => !p.hasPassed,
  );
}

function checkAuctionState(state: GameState): void {
  const active = state.players.filter((p) => !p.hasPassed);
  if (active.length === 0) {
    handleAllPass(state);
  } else if (
    active.length === 1 &&
    state.currentHighBidderPlayerId &&
    active[0].id === state.currentHighBidderPlayerId
  ) {
    finaliseAuction(state);
  } else if (playerBySeat(state, state.auctionTurnSeatIndex).hasPassed) {
    advanceAuctionTurn(state);
  }
}

function submitBid(state: GameState, playerId: string, bid: Bid): boolean {
  const player = playerById(state, playerId);
  if (player.seatIndex !== state.auctionTurnSeatIndex || player.isDashCall) return false;
  if (!isValidBid(bid, state.currentHighBid, state)) return false;
  state.currentHighBid = bid;
  state.currentHighBidderPlayerId = playerId;
  advanceAuctionTurn(state);
  return true;
}

function passBid(state: GameState, playerId: string): void {
  const player = playerById(state, playerId);
  if (player.seatIndex !== state.auctionTurnSeatIndex) return;
  player.hasPassed = true;
  advanceAuctionTurn(state);
}

function getForbiddenDeclaration(state: GameState, playerId: string): number | null {
  const player = playerById(state, playerId);
  if (player.isDashCall) return null;
  const declaredPlayers = state.players.filter((p) => p.declared != null);
  if (declaredPlayers.length === state.players.length - 1) {
    const sum = declaredPlayers.reduce((s, p) => s + (p.declared ?? 0), 0);
    const forbidden = 13 - sum;
    if (forbidden >= 0 && forbidden <= 13) return forbidden;
  }
  return null;
}

function getMaxAllowedDeclaration(state: GameState, playerId: string): number {
  const player = playerById(state, playerId);
  if (player.isDashCall) return 0;
  if (getFixedTrump(state) && !state.bidderPlayerId) return 13;
  if (player.id === state.bidderPlayerId) return 13;
  const bidder = state.bidderPlayerId
    ? playerById(state, state.bidderPlayerId)
    : null;
  if (bidder?.declared != null) return bidder.declared;
  return 13;
}

function submitDeclaration(state: GameState, playerId: string, declared: number): boolean {
  const player = playerById(state, playerId);
  if (player.seatIndex !== state.currentPlayerSeatIndex) return false;
  if (player.isDashCall && declared !== 0) return false;
  if (
    player.id === state.bidderPlayerId &&
    state.currentHighBid &&
    declared < state.currentHighBid.trickCount
  ) {
    return false;
  }
  const maxAllowed = getMaxAllowedDeclaration(state, playerId);
  if (declared > maxAllowed) return false;
  const forbidden = getForbiddenDeclaration(state, playerId);
  if (forbidden != null && declared === forbidden) return false;

  const declaredPlayers = state.players.filter((p) => p.declared != null);
  if (declaredPlayers.length === state.players.length - 1) {
    const sum = declaredPlayers.reduce((s, p) => s + (p.declared ?? 0), 0) + declared;
    if (sum <= 11) player.isRisk = true;
  }

  player.declared = declared;

  if (state.players.every((p) => p.declared != null)) {
    if (getFixedTrump(state) && !state.bidderPlayerId) {
      let highest = -1;
      let winner: Player | null = null;
      const startSeat = (state.dealerSeatIndex + 1) % state.players.length;
      for (let i = 0; i < state.players.length; i++) {
        const p = playerBySeat(state, (startSeat + i) % state.players.length);
        const pDecl = p.declared ?? 0;
        if (pDecl > highest) {
          highest = pDecl;
          winner = p;
        }
      }
      const w = winner ?? state.players[0];
      state.bidderPlayerId = w.id;
      state.trickLeaderSeatIndex = w.seatIndex;
      state.currentPlayerSeatIndex = w.seatIndex;
    } else {
      state.currentPlayerSeatIndex = state.trickLeaderSeatIndex;
    }
    state.phase = "trickTaking";
  } else {
    state.currentPlayerSeatIndex = getNextSeat(
      state,
      state.currentPlayerSeatIndex,
      (p) => p.declared == null,
    );
  }
  return true;
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

function resolveTrickWinner(state: GameState): string {
  const trump = state.trump;
  const ledSuit = state.currentTrick[0].card.suit;

  if (!trump || trump === "sans") {
    const led = state.currentTrick.filter((tc) => tc.card.suit === ledSuit);
    led.sort((a, b) => (RANK_SORT[b.card.rank] ?? 0) - (RANK_SORT[a.card.rank] ?? 0));
    return led[0].playerId;
  }

  const trumpCards = state.currentTrick.filter((tc) => tc.card.suit === trump);
  if (trumpCards.length > 0) {
    trumpCards.sort((a, b) => (RANK_SORT[b.card.rank] ?? 0) - (RANK_SORT[a.card.rank] ?? 0));
    return trumpCards[0].playerId;
  }

  const led = state.currentTrick.filter((tc) => tc.card.suit === ledSuit);
  led.sort((a, b) => (RANK_SORT[b.card.rank] ?? 0) - (RANK_SORT[a.card.rank] ?? 0));
  return led[0].playerId;
}

function resolveTrick(state: GameState): void {
  const winnerId = resolveTrickWinner(state);
  const winner = playerById(state, winnerId);
  winner.takenTricks.push([...state.currentTrick]);
  winner.actual++;
  state.tricksPlayedThisRound++;
  state.currentTrick = [];
  state.trickLeaderSeatIndex = winner.seatIndex;
  state.currentPlayerSeatIndex = winner.seatIndex;
  if (state.tricksPlayedThisRound === K_TRICKS_PER_ROUND) {
    state.phase = "scoring";
  }
}

function playCard(state: GameState, playerId: string, card: Card): boolean {
  const player = playerById(state, playerId);
  if (!canPlayCard(state, player, card)) return false;
  removeCard(player.hand, card);
  state.currentTrick.push({ playerId, card });
  if (state.currentTrick.length < state.players.length) {
    state.currentPlayerSeatIndex = (state.currentPlayerSeatIndex + 1) % state.players.length;
    return false;
  }
  resolveTrick(state);
  return true;
}

function computeAndApplyScores(state: GameState): void {
  const deltas: Record<string, number> = {};
  let totalDeclared = 0;
  let bidderDeclared = 0;
  for (const p of state.players) {
    totalDeclared += p.declared ?? 0;
    if (p.id === state.bidderPlayerId) bidderDeclared = p.declared ?? 0;
  }
  const isUnder = totalDeclared < 13;
  const multiplier = state.isDoubleRound ? 2 : 1;

  for (const p of state.players) {
    const declared = p.declared ?? 0;
    const actual = p.actual;
    const isBidder = p.id === state.bidderPlayerId;
    const isWith = !isBidder && declared === bidderDeclared;
    const isDashCall = p.isDashCall;
    const isRisk = p.isRisk;
    let delta: number;

    if (isDashCall) {
      delta = actual === 0 ? (isUnder ? 25 : 33) : (isUnder ? -25 : -33);
    } else if (actual === declared) {
      delta = actual + state.roundNumber;
      if (isBidder || isWith || isRisk) delta += 10;
      if (isUnder && declared === 0) delta += 10;
    } else {
      delta = -Math.abs(declared - actual) - state.roundNumber;
      if (isBidder || isWith || isRisk) delta -= 10;
    }
    delta *= multiplier;
    p.totalScore += delta;
    deltas[p.id] = delta;
  }
  state.lastRoundScoreDeltas = deltas;
  state.isDoubleRound = false;
}

function resetRoundState(state: GameState): void {
  state.currentHighBid = null;
  state.currentHighBidderPlayerId = null;
  state.bidderPlayerId = null;
  state.trump = getFixedTrump(state);
  state.currentTrick = [];
  state.trickLeaderSeatIndex = 0;
  state.tricksPlayedThisRound = 0;
  state.currentPlayerSeatIndex = 0;
  state.voidCheckPassed = [];
  state.dashCallPassed = [];
}

function startNextRound(state: GameState): void {
  if (state.roundNumber >= state.totalRounds) {
    state.phase = "matchEnd";
    return;
  }
  state.roundNumber++;
  const firstBidder = (state.roundNumber - 1) % state.players.length;
  state.dealerSeatIndex = (firstBidder - 1 + state.players.length) % state.players.length;
  for (const p of state.players) {
    p.hand = [];
    p.takenTricks = [];
    p.declared = null;
    p.actual = 0;
    p.hasPassed = false;
    p.isDashCall = false;
    p.isRisk = false;
  }
  resetRoundState(state);
  state.auctionTurnSeatIndex = firstBidder;
  state.currentPlayerSeatIndex = firstBidder;
  state.phase = "dealing";
}

function isMatchOver(state: GameState): boolean {
  const reachedRound = state.roundNumber >= state.totalRounds &&
    (state.phase === "scoring" || state.phase === "matchEnd");
  const reachedScore = !isRoundBasedBoula(state.totalRounds) &&
    state.players.some((p) => p.totalScore >= K_MATCH_END_SCORE);
  return reachedRound || reachedScore;
}

function doDeal(state: GameState): void {
  const firstBidder = (state.roundNumber - 1) % MAX_PLAYERS;
  state.dealerSeatIndex = (firstBidder - 1 + MAX_PLAYERS) % MAX_PLAYERS;
  state.auctionTurnSeatIndex = firstBidder;
  state.trump = getFixedTrump(state);
  dealCards(state);
  enterPostDealPhase(state);
}

function triggerRedeal(state: GameState): void {
  for (const p of state.players) {
    p.hand = [];
    p.takenTricks = [];
    p.declared = null;
    p.actual = 0;
    p.hasPassed = false;
    p.isDashCall = false;
    p.isRisk = false;
  }
  resetRoundState(state);
  doDeal(state);
}

function ensureBotPlayers(state: GameState): void {
  while (state.players.length < MAX_PLAYERS) {
    const seat = state.players.length;
    state.players.push({
      id: `bot_${seat}_${Date.now()}`,
      name: `Bot ${seat + 1}`,
      seatIndex: seat,
      hand: [],
      takenTricks: [],
      actual: 0,
      hasPassed: false,
      isDashCall: false,
      isRisk: false,
      totalScore: 0,
    });
  }
}

function normalizeState(raw: GameState): GameState {
  const s = cloneState(raw);
  s.dashCallPassed = s.dashCallPassed ?? [];
  s.voidCheckPassed = s.voidCheckPassed ?? [];
  s.voidRedealRejections = s.voidRedealRejections ?? [];
  s.currentTrick = s.currentTrick ?? [];
  s.lastRoundScoreDeltas = s.lastRoundScoreDeltas ?? {};
  s.roundHistory = s.roundHistory ?? [];
  s.cardTheme = s.cardTheme ?? "theme_1";
  s.totalRounds = s.totalRounds ?? K_BOUla_TOTAL_ROUNDS;
  for (const p of s.players) {
    p.hand = p.hand ?? [];
    p.takenTricks = p.takenTricks ?? [];
    p.actual = p.actual ?? 0;
    p.hasPassed = p.hasPassed ?? false;
    p.isDashCall = p.isDashCall ?? false;
    p.isRisk = p.isRisk ?? false;
    p.totalScore = p.totalScore ?? 0;
  }
  return s;
}

/** Main Estimation reducer entry point. */
export function reduceEstimation(input: ReduceInput): ReduceResult {
  const { ctx, actorUid, action, payload } = input;
  const state = normalizeState(ctx.state);
  const isHost = ctx.hostId === actorUid;

  switch (action) {
    case "requestStateSync":
      return {
        ok: true,
        ephemeral: { type: "requestStateSync", playerId: actorUid },
      };

    case "sendReaction":
    case "triggerEarthquake":
      return {
        ok: true,
        ephemeral: {
          type: action,
          playerId: actorUid,
          ...payload,
        },
      };

    case "startGame":
      if (!isHost || state.phase !== "lobby") return errResult("INVALID_START");
      ensureBotPlayers(state);
      state.phase = "dealing";
      doDeal(state);
      return okResult(state);

    case "changeTheme":
      if (!isHost || state.phase !== "lobby") return errResult("INVALID_THEME");
      state.cardTheme = String(payload.theme ?? state.cardTheme);
      return okResult(state);

    case "approveRedeal":
      if (state.phase !== "voidCheck" || !state.voidDeclaringPlayerId) {
        return errResult("WRONG_PHASE");
      }
      triggerRedeal(state);
      return okResult(state);

    case "rejectRedeal":
      if (state.phase !== "voidCheck" || !state.voidDeclaringPlayerId) {
        return errResult("WRONG_PHASE");
      }
      if (!state.voidRedealRejections.includes(actorUid)) {
        state.voidRedealRejections.push(actorUid);
      }
      if (state.voidRedealRejections.length >= state.players.length) {
        proceedAfterVoidCheck(state);
      }
      return okResult(state);

    case "confirmNoVoid":
      if (state.phase !== "voidCheck") return errResult("WRONG_PHASE");
      passVoidCheck(state, actorUid);
      return okResult(state);

    case "unready":
      if (state.phase !== "voidCheck") return errResult("WRONG_PHASE");
      state.voidCheckPassed = state.voidCheckPassed.filter((id) => id !== actorUid);
      return okResult(state);

    case "submitDashCall":
      if (state.phase !== "dashCall") return errResult("WRONG_PHASE");
      submitDashCall(state, actorUid, Boolean(payload.wantsDashCall));
      return okResult(state);

    case "submitBid": {
      if (state.phase !== "auction") return errResult("WRONG_PHASE");
      const bid = payload.bid as Bid;
      if (!bid?.trickCount || !bid?.trump) return errResult("INVALID_BID");
      if (!submitBid(state, actorUid, bid)) return errResult("BID_REJECTED");
      if (state.phase === "dealing") doDeal(state);
      return okResult(state);
    }

    case "passBid":
      if (state.phase !== "auction") return errResult("WRONG_PHASE");
      passBid(state, actorUid);
      if (state.phase === "dealing") doDeal(state);
      return okResult(state);

    case "submitDeclaration": {
      if (state.phase !== "declarations") return errResult("WRONG_PHASE");
      const declared = Number(payload.declared);
      if (!Number.isInteger(declared) || declared < 0 || declared > 13) {
        return errResult("INVALID_DECLARATION");
      }
      if (!submitDeclaration(state, actorUid, declared)) {
        return errResult("DECLARATION_REJECTED");
      }
      return okResult(state);
    }

    case "playCard": {
      if (state.phase !== "trickTaking") return errResult("WRONG_PHASE");
      if (state.currentTrick.length >= state.players.length) {
        return errResult("TRICK_FULL");
      }
      const card = payload.card as Card;
      if (!card?.suit || !card?.rank) return errResult("INVALID_CARD");
      if (!playCard(state, actorUid, card)) return errResult("CARD_REJECTED");
      if (state.phase === "scoring") computeAndApplyScores(state);
      return okResult(state);
    }

    case "nextRound":
      if (!isHost || state.phase !== "scoring") return errResult("INVALID_NEXT_ROUND");
      if (isMatchOver(state)) {
        state.phase = "matchEnd";
      } else {
        startNextRound(state);
        doDeal(state);
      }
      return okResult(state);

    default:
      return errResult("UNSUPPORTED_ACTION");
  }
}
