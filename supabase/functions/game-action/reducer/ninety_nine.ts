// Ninety-Nine authoritative reducer — mirrors ninety_nine_game_engine.dart.

import {
  applyEffect99,
  autoSortHand,
  cardsEqual,
  fullDeck,
  humanHandUpdates,
  isLegalPlay99,
  isReverseCard99,
  resolveActingPlayerId,
  shuffle,
} from "./cards.ts";
import { Card, ReduceInput, ReduceResult, cloneState, errResult } from "./types.ts";

const MAX_LOSSES = 5;

type Phase = "waiting" | "playing" | "roundFinished" | "finished";

interface NinetyNinePlayer {
  id: string;
  name: string;
  hand: Card[];
  isBot: boolean;
  avatarId: string;
}

interface NinetyNineMove {
  playerId: string;
  playerName: string;
  card: Card;
  newGroundTotal: number;
  timestamp: string;
}

interface NinetyNineState {
  groundTotal: number;
  direction: number;
  currentPlayerIndex: number;
  currentRoundNumber: number;
  players: NinetyNinePlayer[];
  playerLosses: Record<string, number>;
  phase: Phase;
  roundLoserId?: string | null;
  matchLoserId?: string | null;
  matchWinnerId?: string | null;
  lastPlayedCard?: Card | null;
  lastPlayedPlayerName?: string | null;
  moveHistory: NinetyNineMove[];
  hostId: string;
  cardTheme: string;
}

function normalizeState(raw: Record<string, unknown>): NinetyNineState {
  const s = cloneState(raw) as NinetyNineState;
  s.groundTotal = s.groundTotal ?? 0;
  s.direction = s.direction ?? 1;
  s.currentPlayerIndex = s.currentPlayerIndex ?? 0;
  s.currentRoundNumber = s.currentRoundNumber ?? 1;
  s.players = s.players ?? [];
  s.playerLosses = s.playerLosses ?? {};
  s.phase = (s.phase ?? "waiting") as Phase;
  s.moveHistory = s.moveHistory ?? [];
  s.hostId = s.hostId ?? "";
  s.cardTheme = s.cardTheme ?? "theme_1";
  for (const p of s.players) {
    p.hand = p.hand ?? [];
    p.isBot = p.isBot ?? false;
    p.avatarId = p.avatarId ?? "avatar_1";
  }
  return s;
}

function currentPlayer(state: NinetyNineState): NinetyNinePlayer | null {
  if (state.players.length === 0) return null;
  return state.players[state.currentPlayerIndex] ?? null;
}

function dealAndStartRound(state: NinetyNineState, roundNumber: number): void {
  state.groundTotal = 0;
  state.direction = 1;
  state.moveHistory = [];
  state.lastPlayedCard = null;
  state.lastPlayedPlayerName = null;
  state.roundLoserId = null;
  state.currentRoundNumber = roundNumber;

  for (const p of state.players) p.hand = [];

  const deck = shuffle(fullDeck());
  let pIndex = 0;
  while (deck.length > 0) {
    state.players[pIndex].hand.push(deck.pop()!);
    pIndex = (pIndex + 1) % state.players.length;
  }
  for (const p of state.players) autoSortHand(p.hand);

  state.currentPlayerIndex = (roundNumber - 1) % state.players.length;
  state.phase = "playing";
}

function playCard(state: NinetyNineState, playerId: string, card: Card): boolean {
  if (state.phase !== "playing") return false;
  const cur = currentPlayer(state);
  if (!cur || cur.id !== playerId) return false;

  const player = state.players.find((p) => p.id === playerId);
  if (!player) return false;

  const cardIdx = player.hand.findIndex((c) => cardsEqual(c, card));
  if (cardIdx === -1) return false;

  if (!isLegalPlay99(state.groundTotal, card)) return false;

  player.hand.splice(cardIdx, 1);
  state.lastPlayedCard = card;
  state.lastPlayedPlayerName = player.name;
  state.groundTotal = applyEffect99(state.groundTotal, card);

  if (isReverseCard99(card)) {
    state.direction = -state.direction;
  }

  state.moveHistory.push({
    playerId: player.id,
    playerName: player.name,
    card,
    newGroundTotal: state.groundTotal,
    timestamp: new Date().toISOString(),
  });

  const n = state.players.length;
  const nextIndex = (state.currentPlayerIndex + state.direction + n) % n;

  const nextPlayer = state.players[nextIndex];
  const hasLegal = nextPlayer.hand.some((c) => isLegalPlay99(state.groundTotal, c));
  if (!hasLegal) {
      state.roundLoserId = nextPlayer.id;
      const losses = (state.playerLosses[nextPlayer.id] ?? 0) + 1;
      state.playerLosses[nextPlayer.id] = losses;

      if (losses >= MAX_LOSSES) {
        state.matchLoserId = nextPlayer.id;
        const sorted = [...state.players].sort(
          (a, b) => (state.playerLosses[a.id] ?? 0) - (state.playerLosses[b.id] ?? 0),
        );
        state.matchWinnerId = sorted[0]?.id ?? null;
        state.phase = "finished";
      } else {
        state.phase = "roundFinished";
      }
      return true;
  }

  state.currentPlayerIndex = nextIndex;
  return true;
}

function ensureBots(state: NinetyNineState, maxPlayers: number): void {
  while (state.players.length < maxPlayers) {
    const i = state.players.length + 1;
    const botId = `bot_${i}`;
    state.players.push({
      id: botId,
      name: `Bot ${i}`,
      hand: [],
      isBot: true,
      avatarId: `avatar_${((i - 1) % 6) + 1}`,
    });
    state.playerLosses[botId] = 0;
  }
}

function ok(state: NinetyNineState): ReduceResult {
  return {
    ok: true,
    nextPublicState: state as unknown as ReduceInput["ctx"]["state"],
    handUpdates: humanHandUpdates(state.players),
  };
}

export function reduceNinetyNine(input: ReduceInput): ReduceResult {
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
      dealAndStartRound(state, 1);
      return ok(state);

    case "playCardNinetyNine": {
      const card = payload.card as Card;
      if (!card?.suit || !card?.rank) return errResult("INVALID_CARD");
      if (!playCard(state, actingId, card)) return errResult("CARD_REJECTED");
      return ok(state);
    }

    case "nextRound":
      if (!isHost || state.phase !== "roundFinished") {
        return errResult("INVALID_NEXT_ROUND");
      }
      dealAndStartRound(state, state.currentRoundNumber + 1);
      return ok(state);

    case "changeTheme":
      if (!isHost) return errResult("HOST_ONLY");
      state.cardTheme = String(payload.theme ?? state.cardTheme);
      return ok(state);

    default:
      return errResult("UNSUPPORTED_ACTION");
  }
}
