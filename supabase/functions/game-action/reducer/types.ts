// Shared types for game-action reducers (W1.1).

export type GamePhase =
  | "lobby"
  | "dealing"
  | "voidCheck"
  | "dashCall"
  | "auction"
  | "declarations"
  | "trickTaking"
  | "scoring"
  | "matchEnd";

export interface Card {
  suit: string;
  rank: string;
}

export interface TrickCard {
  playerId: string;
  card: Card;
}

export interface Player {
  id: string;
  name: string;
  seatIndex: number;
  photo?: string | null;
  hand: Card[];
  takenTricks: TrickCard[][];
  declared?: number | null;
  actual: number;
  hasPassed: boolean;
  isDashCall: boolean;
  isRisk: boolean;
  totalScore: number;
}

export interface Bid {
  trickCount: number;
  trump: string;
}

export interface GameState {
  players: Player[];
  phase: GamePhase;
  roundNumber: number;
  totalRounds: number;
  dealerSeatIndex: number;
  isDoubleRound: boolean;
  dashCallPassed: string[];
  currentHighBid?: Bid | null;
  currentHighBidderPlayerId?: string | null;
  auctionTurnSeatIndex: number;
  bidderPlayerId?: string | null;
  trump?: string | null;
  currentTrick: TrickCard[];
  trickLeaderSeatIndex: number;
  tricksPlayedThisRound: number;
  currentPlayerSeatIndex: number;
  lastRoundScoreDeltas: Record<string, number>;
  roundHistory: unknown[];
  voidCheckPassed: string[];
  voidDeclaringPlayerId?: string | null;
  voidRedealRejections: string[];
  turnDurationSeconds: number;
  turnDeadlineEpochMs?: number | null;
  cardTheme: string;
}

export interface AuthorityContext {
  roomId: string;
  gameType: string;
  hostId: string;
  actionSeq: number;
  state: GameState;
}

export interface ReduceResult {
  ok: boolean;
  error?: string;
  nextPublicState?: GameState;
  handUpdates?: Record<string, Card[]>;
  /** Actions that do not mutate persisted state (reactions, etc.). */
  ephemeral?: Record<string, unknown>;
}

export interface ReduceInput {
  ctx: AuthorityContext;
  actorUid: string;
  action: string;
  payload: Record<string, unknown>;
}

export type Reducer = (input: ReduceInput) => ReduceResult;

export function cloneState(state: GameState): GameState {
  return JSON.parse(JSON.stringify(state)) as GameState;
}

export function playerById(state: GameState, id: string): Player {
  const p = state.players.find((x) => x.id === id);
  if (!p) throw new Error("PLAYER_NOT_FOUND");
  return p;
}

export function playerBySeat(state: GameState, seat: number): Player {
  const p = state.players.find((x) => x.seatIndex === seat);
  if (!p) throw new Error("SEAT_NOT_FOUND");
  return p;
}

export function cardKey(c: Card): string {
  return `${c.suit}_${c.rank}`;
}

export function cardsEqual(a: Card, b: Card): boolean {
  return a.suit === b.suit && a.rank === b.rank;
}

export function handContains(hand: Card[], card: Card): boolean {
  return hand.some((c) => cardsEqual(c, card));
}

export function removeCard(hand: Card[], card: Card): void {
  const idx = hand.findIndex((c) => cardsEqual(c, card));
  if (idx >= 0) hand.splice(idx, 1);
}

export function handUpdatesFromState(state: GameState): Record<string, Card[]> {
  const updates: Record<string, Card[]> = {};
  for (const p of state.players) {
    updates[p.id] = p.hand.map((c) => ({ ...c }));
  }
  return updates;
}

export function okResult(
  state: GameState,
  handUpdates?: Record<string, Card[]>,
): ReduceResult {
  return {
    ok: true,
    nextPublicState: state,
    handUpdates: handUpdates ?? handUpdatesFromState(state),
  };
}

export function errResult(error: string): ReduceResult {
  return { ok: false, error };
}
