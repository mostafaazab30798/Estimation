// Shared card utilities for mode reducers.

import { Card } from "./types.ts";

export const SUITS = ["club", "diamond", "heart", "spade"] as const;
export const RANKS = [
  "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "jack", "queen", "king", "ace",
] as const;

const SUIT_PRIORITY: Record<string, number> = {
  club: 0, diamond: 1, heart: 2, spade: 3,
};

const RANK_SORT: Record<string, number> = Object.fromEntries(
  RANKS.map((r, i) => [r, i]),
);

export function cardId(c: Card): string {
  return `${c.suit}_${c.rank}`;
}

export function cardsEqual(a: Card, b: Card): boolean {
  return a.suit === b.suit && a.rank === b.rank;
}

export function fullDeck(): Card[] {
  const deck: Card[] = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({ suit, rank });
    }
  }
  return deck;
}

export function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function autoSortHand(hand: Card[]): void {
  hand.sort((a, b) => {
    const suitOrder = 3 - (SUIT_PRIORITY[a.suit] ?? 0);
    const rankOrder = 12 - (RANK_SORT[a.rank] ?? 0);
    return suitOrder * 100 + rankOrder;
  });
}

export function isUuid(id: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
}

type BotAwareState = {
  players: Array<{ id: string; isBot?: boolean }>;
  botPlayerIds?: string[];
};

/** True when the seat is bot-controlled (server may act via service_role). */
export function isProxyBotSeat(state: BotAwareState, playerId: string): boolean {
  if (!playerId) return false;
  if (playerId.startsWith("bot_")) return true;
  if (Array.isArray(state.botPlayerIds) && state.botPlayerIds.includes(playerId)) {
    return true;
  }
  const player = state.players.find((p) => p.id === playerId);
  return player?.isBot === true;
}

/** @deprecated Client hosts must not proxy bots; edge function uses service_role. */
export function resolveActingPlayerId(
  actorUid: string,
  _payload: Record<string, unknown>,
  _state: BotAwareState,
  _isHost: boolean,
): string {
  return actorUid;
}

/** Hand updates for owner-only persistence — skip bots / non-uuid ids. */
export function humanHandUpdates(
  players: Array<{ id: string; hand: Card[]; isBot?: boolean }>,
): Record<string, Card[]> {
  const updates: Record<string, Card[]> = {};
  for (const p of players) {
    if (p.isBot || !isUuid(p.id)) continue;
    updates[p.id] = p.hand.map((c) => ({ ...c }));
  }
  return updates;
}

// ── 99 card rules ───────────────────────────────────────────────────────────

export function isSafeCard99(card: Card): boolean {
  return card.rank === "four" || card.rank === "seven" ||
    card.rank === "jack" || card.rank === "king";
}

export function isReverseCard99(card: Card): boolean {
  return card.rank === "seven";
}

export function unclampedEffect99(currentGround: number, card: Card): number {
  switch (card.rank) {
    case "four":
    case "seven":
      return currentGround;
    case "king":
      return currentGround === 99 ? currentGround : 99;
    case "jack":
      return currentGround - 10;
    case "queen":
      return currentGround + 10;
    case "ace":
      return currentGround + 1;
    case "two":
      return currentGround + 2;
    case "three":
      return currentGround + 3;
    case "five":
      return currentGround + 5;
    case "six":
      return currentGround + 6;
    case "eight":
      return currentGround + 8;
    case "nine":
      return currentGround + 9;
    case "ten":
      return currentGround + 10;
    default:
      return currentGround;
  }
}

/** True when this card can be played without making the ground exceed 99. */
export function isLegalPlay99(currentGround: number, card: Card): boolean {
  return unclampedEffect99(currentGround, card) <= 99;
}

export function applyEffect99(currentGround: number, card: Card): number {
  return Math.max(0, Math.min(99, unclampedEffect99(currentGround, card)));
}

// ── Basra card rules ────────────────────────────────────────────────────────

export function basraNumericValue(card: Card): number | null {
  switch (card.rank) {
    case "ace": return 1;
    case "two": return 2;
    case "three": return 3;
    case "four": return 4;
    case "five": return 5;
    case "six": return 6;
    case "seven": return 7;
    case "eight": return 8;
    case "nine": return 9;
    case "ten": return 10;
    default: return null;
  }
}

export function isJack(card: Card): boolean {
  return card.rank === "jack";
}

export function isQueen(card: Card): boolean {
  return card.rank === "queen";
}

export function isKing(card: Card): boolean {
  return card.rank === "king";
}

export function isSevenOfDiamonds(card: Card): boolean {
  return card.rank === "seven" && card.suit === "diamond";
}

export function isInitialTableForbidden(card: Card): boolean {
  return isJack(card) || isSevenOfDiamonds(card);
}

export function isTwoOfSpades(card: Card): boolean {
  return card.rank === "two" && card.suit === "spade";
}

export function isTenOfDiamonds(card: Card): boolean {
  return card.rank === "ten" && card.suit === "diamond";
}

export function basraTableNumericTotal(cards: Card[]): number {
  return cards.reduce((s, c) => s + (basraNumericValue(c) ?? 0), 0);
}
