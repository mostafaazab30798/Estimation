// Shared authority snapshot loading for game-action + bot runner.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { GameState } from "./reducer/types.ts";

export interface LoadedAuthority {
  roomId: string;
  gameType: string;
  hostId: string;
  actionSeq: number;
  maxPlayers: number;
  totalRounds?: number;
  state: Record<string, unknown>;
}

export function authorityContext(authority: LoadedAuthority) {
  return {
    roomId: authority.roomId,
    gameType: authority.gameType,
    hostId: authority.hostId,
    actionSeq: authority.actionSeq,
    maxPlayers: authority.maxPlayers,
    state: authority.state as GameState,
  };
}

/** A signed-in action proves this temporarily bot-controlled seat is human again. */
export function reclaimActingHumanSeat(
  authority: LoadedAuthority,
  playerId: string,
): void {
  const players = authority.state.players;
  if (!Array.isArray(players)) return;
  const player = players.find((raw) =>
    raw && typeof raw === "object" &&
    String((raw as Record<string, unknown>).id) === playerId
  ) as Record<string, unknown> | undefined;
  if (!player || String(player.id).startsWith("bot_")) return;

  player.isBot = false;
  const botIds = authority.state.botPlayerIds;
  if (Array.isArray(botIds)) {
    authority.state.botPlayerIds = botIds.filter((id) => String(id) !== playerId);
  }
}

export async function loadAuthorityState(
  client: SupabaseClient,
  roomId: string,
): Promise<LoadedAuthority | null> {
  const { data, error } = await client.rpc("get_authority_room_state", {
    p_room_id: roomId,
  });

  if (error || !data) return null;

  const row = data as Record<string, unknown>;
  const rawState = row.state;
  const state = (rawState && typeof rawState === "object" && !Array.isArray(rawState)
    ? rawState
    : {}) as Record<string, unknown>;

  const totalRoundsRaw = row.totalRounds;
  const totalRounds = totalRoundsRaw == null
    ? undefined
    : Number(totalRoundsRaw);

  return {
    roomId: String(row.roomId),
    gameType: String(row.gameType ?? "kotchina"),
    hostId: String(row.hostId),
    actionSeq: Number(row.actionSeq ?? 0),
    maxPlayers: Number(row.maxPlayers ?? 4),
    totalRounds: Number.isFinite(totalRounds) ? totalRounds : undefined,
    state,
  };
}

/** Fill players from room_players when the DB snapshot is still empty (first startGame). */
export async function hydrateLobbyPlayers(
  client: SupabaseClient,
  authority: LoadedAuthority,
): Promise<void> {
  const players = authority.state.players;
  const phase = String(authority.state.phase ?? "waiting");
  const needsRoster = !Array.isArray(players) || players.length === 0;
  if (!needsRoster || !["waiting", "lobby"].includes(phase)) return;

  const { data, error } = await client
    .from("room_players")
    .select("player_id, player_name")
    .eq("room_id", authority.roomId)
    .order("joined_at", { ascending: true });

  if (error || !data?.length) return;

  authority.state.players = data.map((row, index) => ({
    id: String(row.player_id),
    name: String(row.player_name),
    seatIndex: index,
    hand: [],
    isBot: false,
    avatarId: "avatar_1",
    capturedCards: [],
    roundScore: 0,
    basraCount: 0,
    takenTricks: [],
    actual: 0,
    hasPassed: false,
    isDashCall: false,
    isRisk: false,
    totalScore: 0,
  }));
  authority.state.hostId = authority.hostId;
  if (!authority.state.phase) {
    authority.state.phase = "waiting";
  }
  if (authority.totalRounds && authority.totalRounds > 0) {
    authority.state.totalRounds = authority.totalRounds;
  }
  if (authority.gameType === "ninety_nine" || authority.gameType === "99") {
    authority.state.playerLosses = authority.state.playerLosses ?? {};
  }
}
