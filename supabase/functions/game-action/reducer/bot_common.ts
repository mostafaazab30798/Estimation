// Shared bot helpers for server-side bot runners.

export interface BotActionPlan {
  action: string;
  playerId: string;
  payload: Record<string, unknown>;
}

type BotAwareState = {
  players: Array<{ id: string; isBot?: boolean }>;
  botPlayerIds?: string[];
};

export function collectBotPlayerIds(state: BotAwareState): Set<string> {
  const ids = new Set<string>();
  for (const id of state.botPlayerIds ?? []) ids.add(id);
  for (const p of state.players) {
    if (p.id.startsWith("bot_") || p.isBot) ids.add(p.id);
  }
  return ids;
}
