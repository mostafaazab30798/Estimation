// Basra authoritative reducer — mirrors basra_game_engine.dart + capture/scoring.

import {
  autoSortHand,
  basraNumericValue,
  basraTableNumericTotal,
  cardId,
  cardsEqual,
  fullDeck,
  humanHandUpdates,
  isInitialTableForbidden,
  isJack,
  isKing,
  isQueen,
  isSevenOfDiamonds,
  isTenOfDiamonds,
  isTwoOfSpades,
  resolveActingPlayerId,
  shuffle,
} from "./cards.ts";
import { Card, ReduceInput, ReduceResult, cloneState, errResult } from "./types.ts";

const K_MATCH_TARGET = 121;
const K_HAND_SIZE = 4;
const K_TABLE_SIZE = 4;
const K_MAJORITY_THRESHOLD = 27;
const K_MAJORITY_POINTS = 30;
const K_BASRA_BONUS = 10;
const K_JACK_POINTS = 1;
const K_ACE_POINTS = 1;
const K_TWO_SPADES = 2;
const K_TEN_DIAMONDS = 3;

type Phase = "waiting" | "playing" | "roundFinished" | "finished";
type BasraType = "none" | "normal" | "sevenOfDiamonds";

interface BasraPlayer {
  id: string;
  name: string;
  hand: Card[];
  capturedCards: Card[];
  isBot: boolean;
  avatarId: string;
  totalScore: number;
  roundScore: number;
  basraCount: number;
}

interface BasraTurnResult {
  playerId: string;
  playedCard: Card;
  capturedCards: Card[];
  tableBefore: Card[];
  tableAfter: Card[];
  wasCapture: boolean;
  wasBasra: boolean;
  basraType: BasraType;
  lastCapturePlayerId?: string | null;
}

interface BasraPlayerScore {
  playerId: string;
  capturedCount: number;
  jackPoints: number;
  acePoints: number;
  twoOfSpadesPoints: number;
  tenOfDiamondsPoints: number;
  basraPoints: number;
  majorityPoints: number;
  carryOverPoints: number;
  roundScore: number;
  totalScore: number;
  basraCount: number;
}

interface BasraState {
  deck: Card[];
  tableCards: Card[];
  players: BasraPlayer[];
  currentPlayerIndex: number;
  dealerPlayerIndex: number;
  currentRoundNumber: number;
  lastCapturePlayerId?: string | null;
  carriedMajorityPoints: number;
  phase: Phase;
  hostId: string;
  cardTheme: string;
  matchWinnerId?: string | null;
  lastTurnResult?: BasraTurnResult | null;
  lastRoundScores: BasraPlayerScore[];
  lastRoundAwardedFinalTable: boolean;
  lastRoundWasTwentySixTie: boolean;
  deckCount?: number;
}

function normalizeState(raw: Record<string, unknown>): BasraState {
  const s = cloneState(raw) as BasraState;
  s.deck = s.deck ?? [];
  s.tableCards = s.tableCards ?? [];
  s.players = s.players ?? [];
  s.currentPlayerIndex = s.currentPlayerIndex ?? 0;
  s.dealerPlayerIndex = s.dealerPlayerIndex ?? 0;
  s.currentRoundNumber = s.currentRoundNumber ?? 1;
  s.carriedMajorityPoints = s.carriedMajorityPoints ?? 0;
  s.phase = (s.phase ?? "waiting") as Phase;
  s.hostId = s.hostId ?? "";
  s.cardTheme = s.cardTheme ?? "theme_1";
  s.lastRoundScores = s.lastRoundScores ?? [];
  s.lastRoundAwardedFinalTable = s.lastRoundAwardedFinalTable ?? false;
  s.lastRoundWasTwentySixTie = s.lastRoundWasTwentySixTie ?? false;
  for (const p of s.players) {
    p.hand = p.hand ?? [];
    p.capturedCards = p.capturedCards ?? [];
    p.isBot = p.isBot ?? false;
    p.totalScore = p.totalScore ?? 0;
    p.roundScore = p.roundScore ?? 0;
    p.basraCount = p.basraCount ?? 0;
  }
  return s;
}

function combinationKey(cards: Card[]): string {
  return cards.map(cardId).sort().join("|");
}

function findBestSumCombination(tableCards: Card[], target: number): Card[] {
  const numeric = tableCards
    .filter((c) => basraNumericValue(c) != null)
    .sort((a, b) => {
      const va = basraNumericValue(a)!;
      const vb = basraNumericValue(b)!;
      if (va !== vb) return va - vb;
      return cardId(a).localeCompare(cardId(b));
    });

  let best: Card[] | null = null;
  let bestKey: string | null = null;

  function search(start: number, remaining: number, path: Card[]): void {
    if (remaining === 0) {
      const key = combinationKey(path);
      if (
        !best ||
        path.length > best.length ||
        (path.length === best.length && key < bestKey!)
      ) {
        best = [...path];
        bestKey = key;
      }
      return;
    }
    for (let i = start; i < numeric.length; i++) {
      const value = basraNumericValue(numeric[i])!;
      if (value > remaining) break;
      path.push(numeric[i]);
      search(i + 1, remaining - value, path);
      path.pop();
    }
  }

  search(0, target, []);
  return best ?? [];
}

function resolveDeterministicCapture(played: Card, table: Card[]): Card[] {
  const sameRank = table.filter((c) => c.rank === played.rank);
  const sameIds = new Set(sameRank.map(cardId));
  let sumCombo: Card[] = [];
  const numVal = basraNumericValue(played);
  if (numVal != null) {
    const remaining = table.filter((c) => !sameIds.has(cardId(c)));
    sumCombo = findBestSumCombination(remaining, numVal);
  }
  const captured = [...sameRank];
  const seen = new Set(sameIds);
  for (const c of sumCombo) {
    if (!seen.has(cardId(c))) {
      captured.push(c);
      seen.add(cardId(c));
    }
  }
  captured.sort((a, b) => cardId(a).localeCompare(cardId(b)));
  return captured;
}

function sevenBasraEligible(table: Card[]): boolean {
  if (table.some((c) => isQueen(c) || isKing(c))) return false;
  return basraTableNumericTotal(table) <= 10;
}

function detectBasra(
  played: Card,
  tableBefore: Card[],
  captured: Card[],
): BasraType {
  if (tableBefore.length === 0) return "none";
  if (captured.length !== tableBefore.length) return "none";
  const capIds = new Set(captured.map(cardId));
  const tabIds = new Set(tableBefore.map(cardId));
  if (capIds.size !== tabIds.size) return "none";
  for (const id of tabIds) if (!capIds.has(id)) return "none";
  if (isJack(played)) return "none";
  if (isSevenOfDiamonds(played)) {
    return sevenBasraEligible(tableBefore) ? "sevenOfDiamonds" : "none";
  }
  return "normal";
}

/** Exported for server bot planner — does not mutate game state. */
export function previewBasraPlay(played: Card, tableCards: Card[]) {
  return resolvePlay(played, tableCards);
}

function resolvePlay(played: Card, tableCards: Card[]) {
  const tableBefore = [...tableCards];

  if (isJack(played) || isSevenOfDiamonds(played)) {
    if (tableBefore.length === 0) {
      return {
        captured: [] as Card[],
        tableAfter: [played],
        wasCapture: false,
        basraType: "none" as BasraType,
      };
    }
    const basraType = detectBasra(played, tableBefore, tableBefore);
    return {
      captured: [...tableBefore],
      tableAfter: [] as Card[],
      wasCapture: true,
      basraType,
    };
  }

  const captured = resolveDeterministicCapture(played, tableBefore);
  if (captured.length === 0) {
    return {
      captured: [] as Card[],
      tableAfter: [...tableBefore, played],
      wasCapture: false,
      basraType: "none" as BasraType,
    };
  }

  const capIds = new Set(captured.map(cardId));
  const tableAfter = tableBefore.filter((c) => !capIds.has(cardId(c)));
  const basraType = detectBasra(played, tableBefore, captured);
  return { captured, tableAfter, wasCapture: true, basraType };
}

function scoreBreakdown(captured: Card[], basraCount: number) {
  const jackPoints = captured.filter((c) => isJack(c)).length * K_JACK_POINTS;
  const acePoints = captured.filter((c) => c.rank === "ace").length * K_ACE_POINTS;
  const twoSp = captured.some((c) => isTwoOfSpades(c)) ? K_TWO_SPADES : 0;
  const tenD = captured.some((c) => isTenOfDiamonds(c)) ? K_TEN_DIAMONDS : 0;
  const basraPts = basraCount * K_BASRA_BONUS;
  const majorityPts = captured.length >= K_MAJORITY_THRESHOLD ? K_MAJORITY_POINTS : 0;
  return {
    capturedCount: captured.length,
    jackPoints,
    acePoints,
    twoOfSpadesPoints: twoSp,
    tenOfDiamondsPoints: tenD,
    basraPoints: basraPts,
    majorityPoints: majorityPts,
    total: majorityPts + jackPoints + acePoints + twoSp + tenD + basraPts,
  };
}

function isTwentySixTie(players: BasraPlayer[]): boolean {
  const with26 = players.filter((p) => p.capturedCards.length === 26).length;
  return with26 === 2 &&
    players.every((p) => p.capturedCards.length < K_MAJORITY_THRESHOLD);
}

function majorityWinner(players: BasraPlayer[]): BasraPlayer | null {
  let winner: BasraPlayer | null = null;
  for (const p of players) {
    if (p.capturedCards.length >= K_MAJORITY_THRESHOLD) {
      if (winner) return winner;
      winner = p;
    }
  }
  return winner;
}

function matchWinner(state: BasraState): BasraPlayer | null {
  let winner: BasraPlayer | null = null;
  for (const p of state.players) {
    if (p.totalScore < K_MATCH_TARGET) continue;
    if (
      !winner ||
      p.totalScore > winner.totalScore ||
      (p.totalScore === winner.totalScore &&
        state.players.indexOf(p) < state.players.indexOf(winner))
    ) {
      winner = p;
    }
  }
  return winner;
}

function dealInitialCards(state: BasraState, deck?: Card[]): void {
  const source = deck ? [...deck] : shuffle(fullDeck());
  for (const p of state.players) {
    p.hand = [];
    p.capturedCards = [];
  }
  state.tableCards = [];

  for (let i = 0; i < K_HAND_SIZE; i++) {
    for (const p of state.players) {
      if (source.length === 0) break;
      p.hand.push(source.pop()!);
    }
  }
  for (let i = 0; i < K_TABLE_SIZE; i++) {
    if (source.length === 0) break;
    state.tableCards.push(source.pop()!);
  }
  state.deck = source;
  for (const p of state.players) autoSortHand(p.hand);
}

function replaceInitialSpecialTable(state: BasraState): void {
  let guard = 0;
  while (
    state.tableCards.some((c) => isInitialTableForbidden(c)) &&
    state.deck.length > 0 &&
    guard < 60
  ) {
    guard++;
    for (let i = 0; i < state.tableCards.length; i++) {
      if (!isInitialTableForbidden(state.tableCards[i])) continue;
      if (state.deck.length === 0) return;
      const special = state.tableCards[i];
      state.deck.unshift(special);
      state.tableCards[i] = state.deck.pop()!;
    }
  }
}

function initializeRound(state: BasraState): void {
  for (const p of state.players) {
    p.hand = [];
    p.capturedCards = [];
    p.roundScore = 0;
    p.basraCount = 0;
  }
  state.tableCards = [];
  state.lastCapturePlayerId = null;
  state.lastTurnResult = null;
  state.lastRoundScores = [];
  state.lastRoundAwardedFinalTable = false;
  state.lastRoundWasTwentySixTie = false;
  state.matchWinnerId = null;

  state.dealerPlayerIndex = (state.currentRoundNumber - 1) % state.players.length;
  state.currentPlayerIndex = (state.dealerPlayerIndex + 1) % state.players.length;

  dealInitialCards(state);
  replaceInitialSpecialTable(state);
  state.phase = "playing";
}

function startMatch(state: BasraState): void {
  state.currentRoundNumber = 1;
  state.carriedMajorityPoints = 0;
  state.matchWinnerId = null;
  state.lastRoundScores = [];
  state.lastTurnResult = null;
  for (const p of state.players) p.totalScore = 0;
  initializeRound(state);
}

function dealNextHands(state: BasraState): void {
  if (!state.players.every((p) => p.hand.length === 0)) return;
  if (state.deck.length === 0) return;
  for (let i = 0; i < K_HAND_SIZE; i++) {
    for (const p of state.players) {
      if (state.deck.length === 0) break;
      p.hand.push(state.deck.pop()!);
    }
  }
  for (const p of state.players) autoSortHand(p.hand);
}

function finishRound(state: BasraState): void {
  state.lastRoundAwardedFinalTable = false;
  if (state.tableCards.length > 0 && state.lastCapturePlayerId) {
    const capturer = state.players.find((p) => p.id === state.lastCapturePlayerId);
    if (capturer) {
      capturer.capturedCards.push(...state.tableCards);
      state.tableCards = [];
      state.lastRoundAwardedFinalTable = true;
    }
  }

  const wasTie = isTwentySixTie(state.players);
  state.lastRoundWasTwentySixTie = wasTie;
  const majority = majorityWinner(state.players);
  const carryToApply = !wasTie && majority ? state.carriedMajorityPoints : 0;

  const scores: BasraPlayerScore[] = [];
  for (const player of state.players) {
    const breakdown = scoreBreakdown(player.capturedCards, player.basraCount);
    const carry = player.id === majority?.id ? carryToApply : 0;
    const roundScore = breakdown.total + carry;
    player.roundScore = roundScore;
    player.totalScore += roundScore;
    scores.push({
      playerId: player.id,
      capturedCount: breakdown.capturedCount,
      jackPoints: breakdown.jackPoints,
      acePoints: breakdown.acePoints,
      twoOfSpadesPoints: breakdown.twoOfSpadesPoints,
      tenOfDiamondsPoints: breakdown.tenOfDiamondsPoints,
      basraPoints: breakdown.basraPoints,
      majorityPoints: breakdown.majorityPoints,
      carryOverPoints: carry,
      roundScore,
      totalScore: player.totalScore,
      basraCount: player.basraCount,
    });
  }
  state.lastRoundScores = scores;

  if (wasTie) {
    state.carriedMajorityPoints += K_MAJORITY_POINTS;
  } else if (majority) {
    state.carriedMajorityPoints = 0;
  }

  const winner = matchWinner(state);
  if (winner) {
    state.matchWinnerId = winner.id;
    state.phase = "finished";
  } else {
    state.phase = "roundFinished";
  }
}

function playCard(state: BasraState, playerId: string, card: Card): boolean {
  if (state.phase !== "playing" || state.matchWinnerId) return false;
  const cur = state.players[state.currentPlayerIndex];
  if (!cur || cur.id !== playerId) return false;
  if (!cur.hand.some((c) => cardsEqual(c, card))) return false;

  const tableBefore = [...state.tableCards];
  cur.hand = cur.hand.filter((c) => !cardsEqual(c, card));

  const resolved = resolvePlay(card, tableBefore);
  state.tableCards = [...resolved.tableAfter];

  if (resolved.wasCapture) {
    cur.capturedCards.push(...resolved.captured, card);
    state.lastCapturePlayerId = playerId;
    if (resolved.basraType !== "none") {
      cur.basraCount += 1;
      cur.roundScore += K_BASRA_BONUS;
    }
  }

  state.lastTurnResult = {
    playerId,
    playedCard: card,
    capturedCards: resolved.captured,
    tableBefore,
    tableAfter: [...state.tableCards],
    wasCapture: resolved.wasCapture,
    wasBasra: resolved.basraType !== "none",
    basraType: resolved.basraType,
    lastCapturePlayerId: state.lastCapturePlayerId,
  };

  const allEmpty = state.players.every((p) => p.hand.length === 0);
  if (allEmpty) {
    if (state.deck.length > 0) {
      dealNextHands(state);
      state.currentPlayerIndex = (state.currentPlayerIndex + 1) % state.players.length;
    } else {
      finishRound(state);
    }
    return true;
  }

  state.currentPlayerIndex = (state.currentPlayerIndex + 1) % state.players.length;
  return true;
}

function ensureBots(state: BasraState, maxPlayers: number): void {
  while (state.players.length < maxPlayers) {
    const i = state.players.length + 1;
    state.players.push({
      id: `bot_${i}`,
      name: `Bot ${i}`,
      hand: [],
      capturedCards: [],
      isBot: true,
      avatarId: `avatar_${((i - 1) % 6) + 1}`,
      totalScore: 0,
      roundScore: 0,
      basraCount: 0,
    });
  }
}

function ok(state: BasraState): ReduceResult {
  return {
    ok: true,
    nextPublicState: state as unknown as ReduceInput["ctx"]["state"],
    handUpdates: humanHandUpdates(state.players),
  };
}

export function reduceBasra(input: ReduceInput): ReduceResult {
  const { ctx, actorUid, action, payload } = input;
  const state = normalizeState(ctx.state as unknown as Record<string, unknown>);
  const isHost = ctx.hostId === actorUid;
  const actingId = resolveActingPlayerId(actorUid, payload, state, isHost);
  const maxPlayers = ctx.maxPlayers || 2;

  switch (action) {
    case "requestStateSync":
      return { ok: true, ephemeral: { type: "requestStateSync", playerId: actorUid } };

    case "sendReaction":
    case "triggerEarthquake":
      return { ok: true, ephemeral: { type: action, playerId: actorUid, ...payload } };

    case "startGame":
      if (!isHost || state.phase !== "waiting") return errResult("INVALID_START");
      ensureBots(state, maxPlayers);
      startMatch(state);
      return ok(state);

    case "playCardBasra": {
      const card = payload.card as Card;
      if (!card?.suit || !card?.rank) return errResult("INVALID_CARD");
      if (!playCard(state, actingId, card)) return errResult("CARD_REJECTED");
      return ok(state);
    }

    case "nextRound":
      if (!isHost || state.phase !== "roundFinished") {
        return errResult("INVALID_NEXT_ROUND");
      }
      state.currentRoundNumber += 1;
      initializeRound(state);
      return ok(state);

    case "changeTheme":
      if (!isHost) return errResult("HOST_ONLY");
      state.cardTheme = String(payload.theme ?? state.cardTheme);
      return ok(state);

    default:
      return errResult("UNSUPPORTED_ACTION");
  }
}
