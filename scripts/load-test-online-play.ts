#!/usr/bin/env -S deno run --allow-net --allow-env --allow-read

/**
 * Staging load test: concurrent online play across Estimation, Basra, and 99.
 *
 * Usage:
 *   SUPABASE_SERVICE_ROLE_KEY=... deno run -A scripts/load-test-online-play.ts
 *   deno run -A scripts/load-test-online-play.ts --users 50 --duration 90
 *
 * Requires config/env.staging.json (or --env path). Never commit service role keys.
 */

import { parseArgs } from "jsr:@std/cli/parse-args";

type GameType = "kotchina" | "basra" | "ninety_nine";

interface EnvConfig {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
}

interface TestUser {
  index: number;
  email: string;
  password: string;
  userId: string;
  accessToken: string;
  playerName: string;
}

interface RoomAssignment {
  roomId: string;
  gameType: GameType;
  kind: "private" | "matchmaking";
  hostUserId: string;
  playerIds: string[];
  totalRounds?: number;
}

interface LatencySample {
  op: string;
  ms: number;
  ok: boolean;
  status?: number;
  error?: string;
}

const PASSWORD = "LoadTest!2026Pass";
const RUN_ID = new Date().toISOString().replace(/[-:TZ.]/g, "").slice(0, 14);

const args = parseArgs(Deno.args, {
  string: ["env", "users", "duration", "run-id"],
  default: {
    env: "config/env.staging.json",
    users: "50",
    duration: "90",
    "run-id": RUN_ID,
  },
});

const USER_COUNT = Math.max(4, parseInt(args.users, 10) || 50);
const DURATION_SEC = Math.max(30, parseInt(args.duration, 10) || 90);
const RUN_TAG = args["run-id"] as string;

const samples: LatencySample[] = [];
const errors: Record<string, number> = {};

function bumpError(key: string) {
  errors[key] = (errors[key] ?? 0) + 1;
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil((p / 100) * sorted.length) - 1),
  );
  return sorted[idx];
}

function summarize(op: string, subset: LatencySample[]) {
  const ok = subset.filter((s) => s.ok);
  const latencies = ok.map((s) => s.ms);
  return {
    op,
    total: subset.length,
    success: ok.length,
    failed: subset.length - ok.length,
    successRate: subset.length ? (ok.length / subset.length) * 100 : 0,
    latencyMs: {
      min: latencies.length ? Math.min(...latencies) : 0,
      p50: percentile(latencies, 50),
      p95: percentile(latencies, 95),
      p99: percentile(latencies, 99),
      max: latencies.length ? Math.max(...latencies) : 0,
      avg: latencies.length
        ? latencies.reduce((a, b) => a + b, 0) / latencies.length
        : 0,
    },
  };
}

async function timed<T>(
  op: string,
  fn: () => Promise<T>,
): Promise<T> {
  const start = performance.now();
  try {
    const result = await fn();
    samples.push({ op, ms: performance.now() - start, ok: true });
    return result;
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    samples.push({
      op,
      ms: performance.now() - start,
      ok: false,
      error: message,
    });
    bumpError(`${op}:${message.slice(0, 80)}`);
    throw e;
  }
}

async function loadConfig(path: string): Promise<EnvConfig> {
  const raw = await Deno.readTextFile(path);
  const cfg = JSON.parse(raw) as EnvConfig;
  if (!cfg.SUPABASE_URL || !cfg.SUPABASE_ANON_KEY) {
    throw new Error(`Missing SUPABASE_URL or SUPABASE_ANON_KEY in ${path}`);
  }
  return cfg;
}

function serviceRoleKey(): string {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key) {
    throw new Error(
      "Set SUPABASE_SERVICE_ROLE_KEY in the environment before running.",
    );
  }
  return key;
}

async function adminFetch(
  cfg: EnvConfig,
  serviceKey: string,
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const url = `${cfg.SUPABASE_URL}${path}`;
  return fetch(url, {
    ...init,
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

async function userFetch(
  cfg: EnvConfig,
  token: string,
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const url = `${cfg.SUPABASE_URL}${path}`;
  return fetch(url, {
    ...init,
    headers: {
      apikey: cfg.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

async function rpc<T>(
  cfg: EnvConfig,
  token: string,
  name: string,
  params: Record<string, unknown>,
): Promise<T> {
  return timed(`rpc:${name}`, async () => {
    const res = await userFetch(cfg, token, `/rest/v1/rpc/${name}`, {
      method: "POST",
      body: JSON.stringify(params),
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`${name} ${res.status} ${text.slice(0, 200)}`);
    }
    return text ? JSON.parse(text) as T : (null as T);
  });
}

async function gameAction(
  cfg: EnvConfig,
  token: string,
  roomId: string,
  action: string,
  payload: Record<string, unknown> = {},
): Promise<Record<string, unknown>> {
  return timed(`edge:game-action:${action}`, async () => {
    const res = await userFetch(cfg, token, `/functions/v1/game-action`, {
      method: "POST",
      body: JSON.stringify({
        roomId,
        action,
        payload,
        actionId: crypto.randomUUID(),
      }),
    });
    const text = await res.text();
    let data: Record<string, unknown> = {};
    try {
      data = text ? JSON.parse(text) as Record<string, unknown> : {};
    } catch {
      data = { raw: text };
    }
    if (res.status >= 400) {
      const detail = JSON.stringify(data);
      throw new Error(
        `${action} ${res.status} ${String(data.error ?? text).slice(0, 120)} body=${detail.slice(0, 300)}`,
      );
    }
    return data;
  });
}

async function ensureUser(
  cfg: EnvConfig,
  serviceKey: string,
  index: number,
): Promise<TestUser> {
  const email = `lt${RUN_TAG.slice(-6)}${String(index).padStart(2, "0")}@lt.local`;
  const playerName = `LT${index}`;

  await timed("admin:create_user", async () => {
    const res = await adminFetch(cfg, serviceKey, "/auth/v1/admin/users", {
      method: "POST",
      body: JSON.stringify({
        email,
        password: PASSWORD,
        email_confirm: true,
        user_metadata: {
          load_test: RUN_TAG,
          index,
          name: playerName,
          full_name: playerName,
        },
      }),
    });
    if (res.status === 422) {
      // Already exists from a partial run — ok.
      return;
    }
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`create_user ${res.status} ${text.slice(0, 200)}`);
    }
  });

  const signIn = await timed("auth:sign_in", async () => {
    const res = await userFetch(cfg, cfg.SUPABASE_ANON_KEY, "/auth/v1/token?grant_type=password", {
      method: "POST",
      body: JSON.stringify({ email, password: PASSWORD }),
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`sign_in ${res.status} ${text.slice(0, 200)}`);
    }
    return JSON.parse(text) as {
      access_token: string;
      user: { id: string };
    };
  });

  return {
    index,
    email,
    password: PASSWORD,
    userId: signIn.user.id,
    accessToken: signIn.access_token,
    playerName,
  };
}

function randomRoomCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

function buildRoomPlan(userCount: number): Array<{
  kind: "private" | "matchmaking";
  gameType: GameType;
  players: number;
  totalRounds?: number;
}> {
  const plans: Array<{
    kind: "private" | "matchmaking";
    gameType: GameType;
    players: number;
    totalRounds?: number;
  }> = [];

  const targets: Array<{ kind: "private" | "matchmaking"; gameType: GameType; totalRounds?: number }> = [
    { kind: "matchmaking", gameType: "kotchina", totalRounds: 5 },
    { kind: "matchmaking", gameType: "kotchina", totalRounds: 10 },
    { kind: "matchmaking", gameType: "kotchina", totalRounds: 15 },
    { kind: "matchmaking", gameType: "kotchina", totalRounds: 20 },
    { kind: "private", gameType: "kotchina" },
    { kind: "private", gameType: "kotchina" },
    { kind: "private", gameType: "kotchina" },
    { kind: "private", gameType: "kotchina" },
    { kind: "private", gameType: "basra" },
    { kind: "private", gameType: "basra" },
    { kind: "private", gameType: "ninety_nine" },
    { kind: "private", gameType: "ninety_nine" },
  ];

  let remaining = userCount;
  for (const target of targets) {
    if (remaining < 4) break;
    plans.push({ ...target, players: 4 });
    remaining -= 4;
  }

  while (remaining >= 4) {
    plans.push({ kind: "private", gameType: "kotchina", players: 4 });
    remaining -= 4;
  }

  return plans;
}

async function createPrivateRoom(
  cfg: EnvConfig,
  serviceKey: string,
  host: TestUser,
  joiners: TestUser[],
  gameType: GameType,
): Promise<string> {
  const code = randomRoomCode();

  const roomRow = await timed("admin:create_private_room", async () => {
    const res = await adminFetch(cfg, serviceKey, "/rest/v1/game_rooms", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        room_code: code,
        host_id: host.userId,
        status: "waiting",
        max_players: 4,
        host_ip: "127.0.0.1",
        ws_port: 0,
        game_type: gameType,
        room_kind: "private",
        matchmaking_state: "none",
      }),
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`insert game_room ${res.status} ${text.slice(0, 200)}`);
    }
    const rows = JSON.parse(text) as Array<{ id: string }>;
    return rows[0];
  });

  const roomId = roomRow.id;

  await timed("admin:insert_room_players", async () => {
    const players = [host, ...joiners].map((user, index) => ({
      room_id: roomId,
      player_id: user.userId,
      player_name: user.playerName,
      is_host: index === 0,
      is_online: true,
    }));
    const res = await adminFetch(cfg, serviceKey, "/rest/v1/room_players", {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify(players),
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`insert room_players ${res.status} ${text.slice(0, 200)}`);
    }
  });

  for (const user of [host, ...joiners]) {
    await rpc(cfg, user.accessToken, "player_heartbeat", { p_room_id: roomId });
  }

  await rpc(cfg, host.accessToken, "start_game_room", { p_room_id: roomId });
  return roomId;
}

async function setupRooms(
  cfg: EnvConfig,
  serviceKey: string,
  users: TestUser[],
): Promise<RoomAssignment[]> {
  const plans = buildRoomPlan(users.length);
  const assignments: RoomAssignment[] = [];
  let cursor = 0;

  for (const plan of plans) {
    const slice = users.slice(cursor, cursor + plan.players);
    if (slice.length < plan.players) break;
    cursor += plan.players;

    const host = slice[0];
    let roomId = "";

    if (plan.kind === "matchmaking") {
      let hostUserId = host.userId;
      for (const user of slice) {
        const result = await rpc<Record<string, unknown>>(cfg, user.accessToken, "enter_matchmaking", {
          p_player_name: user.playerName,
          p_game_type: plan.gameType,
          p_total_rounds: plan.totalRounds ?? 5,
        });
        roomId = String(result.room_id);
        hostUserId = String(result.host_id ?? hostUserId);
        await rpc(cfg, user.accessToken, "player_heartbeat", { p_room_id: roomId });
      }
      const hostInfo = slice.find((u) => u.userId === hostUserId) ?? host;

      await rpc(cfg, hostInfo.accessToken, "start_matchmaking_room", {
        p_room_id: roomId,
      });
    } else {
      roomId = await createPrivateRoom(
        cfg,
        serviceKey,
        host,
        slice.slice(1),
        plan.gameType,
      );
    }

    await gameAction(cfg, host.accessToken, roomId, "startGame");

    assignments.push({
      roomId,
      gameType: plan.gameType,
      kind: plan.kind,
      hostUserId: host.userId,
      playerIds: slice.map((u) => u.userId),
      totalRounds: plan.totalRounds,
    });
  }

  return assignments;
}

function findPlayerSeat(
  state: Record<string, unknown>,
  userId: string,
): Record<string, unknown> | null {
  const players = state.players as Array<Record<string, unknown>> | undefined;
  if (!players) return null;
  return players.find((p) => p.id === userId) ?? null;
}

function seatIndex(state: Record<string, unknown>, userId: string): number | null {
  const p = findPlayerSeat(state, userId);
  if (!p) return null;
  const idx = p.seatIndex;
  return typeof idx === "number" ? idx : null;
}

async function getPublicState(
  cfg: EnvConfig,
  token: string,
  roomId: string,
): Promise<Record<string, unknown> | null> {
  return timed("rpc:get_room_public_state", async () => {
    const res = await userFetch(cfg, token, `/rest/v1/rpc/get_room_public_state`, {
      method: "POST",
      body: JSON.stringify({ p_room_id: roomId }),
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`get_room_public_state ${res.status} ${text.slice(0, 120)}`);
    }
    return text ? JSON.parse(text) as Record<string, unknown> : null;
  });
}

async function getHand(
  cfg: EnvConfig,
  token: string,
  roomId: string,
): Promise<Array<{ suit: string; rank: string }>> {
  return timed("rpc:get_my_hand_cards", async () => {
    const res = await userFetch(cfg, token, `/rest/v1/rpc/get_my_hand_cards`, {
      method: "POST",
      body: JSON.stringify({ p_room_id: roomId }),
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`get_my_hand_cards ${res.status} ${text.slice(0, 120)}`);
    }
    return text ? JSON.parse(text) as Array<{ suit: string; rank: string }> : [];
  });
}

async function tryAdvanceGame(
  cfg: EnvConfig,
  user: TestUser,
  room: RoomAssignment,
): Promise<void> {
  const state = await getPublicState(cfg, user.accessToken, room.roomId);
  if (!state) return;

  const phase = String(state.phase ?? "");
  const mySeat = seatIndex(state, user.userId);
  const isHost = user.userId === room.hostUserId;

  if (room.gameType === "kotchina") {
    if (phase === "voidCheck") {
      if (!Array.isArray(state.voidCheckPassed) ||
        !(state.voidCheckPassed as string[]).includes(user.userId)) {
        await gameAction(cfg, user.accessToken, room.roomId, "confirmNoVoid");
      }
      return;
    }
    if (phase === "dashCall") {
      if (mySeat === state.currentPlayerSeatIndex) {
        await gameAction(cfg, user.accessToken, room.roomId, "submitDashCall", {
          wantsDashCall: false,
        });
      }
      return;
    }
    if (phase === "auction") {
      if (mySeat === state.auctionTurnSeatIndex) {
        await gameAction(cfg, user.accessToken, room.roomId, "passBid");
      }
      return;
    }
    if (phase === "declarations") {
      if (mySeat === state.currentPlayerSeatIndex) {
        await gameAction(cfg, user.accessToken, room.roomId, "submitDeclaration", {
          trickCount: 5,
        });
      }
      return;
    }
    if (phase === "trickTaking") {
      if (mySeat === state.currentPlayerSeatIndex) {
        const hand = await getHand(cfg, user.accessToken, room.roomId);
        if (hand.length > 0) {
          await gameAction(cfg, user.accessToken, room.roomId, "playCard", {
            card: hand[0],
          });
        }
      }
      return;
    }
    if (phase === "roundFinished" && isHost) {
      await gameAction(cfg, user.accessToken, room.roomId, "nextRound");
    }
    return;
  }

  if (room.gameType === "basra" || room.gameType === "ninety_nine") {
    const currentSeat = state.currentPlayerSeatIndex;
    if (typeof currentSeat === "number" && mySeat === currentSeat) {
      const hand = await getHand(cfg, user.accessToken, room.roomId);
      if (hand.length > 0) {
        const action = room.gameType === "basra"
          ? "playCardBasra"
          : "playCardNinetyNine";
        await gameAction(cfg, user.accessToken, room.roomId, action, {
          card: hand[0],
        });
      }
    } else if (phase === "roundFinished" && isHost) {
      await gameAction(cfg, user.accessToken, room.roomId, "nextRound");
    }
  }
}

async function playerLoop(
  cfg: EnvConfig,
  user: TestUser,
  room: RoomAssignment,
  endAt: number,
): Promise<void> {
  while (Date.now() < endAt) {
    try {
      await rpc(cfg, user.accessToken, "player_heartbeat", {
        p_room_id: room.roomId,
      });
      await tryAdvanceGame(cfg, user, room);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.includes("NOT_YOUR_TURN") || msg.includes("WRONG_PHASE") ||
        msg.includes("CARD_REJECTED") || msg.includes("BID_REJECTED")) {
        // Expected contention while other seats / bots act.
      } else if (msg.includes("RATE_LIMIT_EXCEEDED")) {
        bumpError("RATE_LIMIT_EXCEEDED");
        await delay(1500);
      } else {
        bumpError(`player:${msg.slice(0, 80)}`);
      }
    }
    await delay(800 + Math.floor(Math.random() * 700));
  }
}

function delay(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

async function cleanup(
  cfg: EnvConfig,
  serviceKey: string,
  users: TestUser[],
): Promise<void> {
  console.log("\nCleaning up load-test users and rooms...");
  for (const user of users) {
    try {
      await adminFetch(
        cfg,
        serviceKey,
        `/auth/v1/admin/users/${user.userId}`,
        { method: "DELETE" },
      );
    } catch {
      // best effort
    }
  }
}

async function main() {
  const cfg = await loadConfig(args.env as string);
  const serviceKey = serviceRoleKey();

  console.log("=== Estimation Online Load Test ===");
  console.log(`Target: ${cfg.SUPABASE_URL}`);
  console.log(`Users: ${USER_COUNT} | Duration: ${DURATION_SEC}s | Run: ${RUN_TAG}`);

  const setupStarted = performance.now();
  console.log("\n[1/4] Creating and signing in users...");
  const users: TestUser[] = [];
  for (let i = 0; i < USER_COUNT; i++) {
    const user = await ensureUser(cfg, serviceKey, i + 1);
    users.push(user);
    if ((i + 1) % 10 === 0 || i + 1 === USER_COUNT) {
      console.log(`  ${i + 1}/${USER_COUNT} ready`);
    }
    if (i + 1 < USER_COUNT) {
      await delay(120);
    }
  }

  console.log("\n[2/4] Creating mixed-mode rooms and starting games...");
  const rooms = await setupRooms(cfg, serviceKey, users);
  const usedIds = new Set(rooms.flatMap((r) => r.playerIds));
  const setupMs = performance.now() - setupStarted;

  console.log(`  Rooms: ${rooms.length} | Active players: ${usedIds.size}`);
  for (const room of rooms) {
    console.log(
      `    - ${room.kind} ${room.gameType} room ${room.roomId.slice(0, 8)}… (${room.playerIds.length} humans)`,
    );
  }

  const userRoom = new Map<string, RoomAssignment>();
  for (const room of rooms) {
    for (const pid of room.playerIds) {
      userRoom.set(pid, room);
    }
  }

  console.log("\n[3/4] Simulating concurrent play + heartbeats...");
  const endAt = Date.now() + DURATION_SEC * 1000;
  const playStarted = performance.now();
  await Promise.all(
    users
      .filter((u) => userRoom.has(u.userId))
      .map((u) => playerLoop(cfg, u, userRoom.get(u.userId)!, endAt)),
  );
  const playMs = performance.now() - playStarted;

  console.log("\n[4/4] Aggregating metrics...");
  const byOp = new Map<string, LatencySample[]>();
  for (const s of samples) {
    const bucket = byOp.get(s.op) ?? [];
    bucket.push(s);
    byOp.set(s.op, bucket);
  }

  const summaries = [...byOp.entries()]
    .map(([op, subset]) => summarize(op, subset))
    .sort((a, b) => a.op.localeCompare(b.op));

  const edgeSamples = samples.filter((s) => s.op.startsWith("edge:"));
  const rpcSamples = samples.filter((s) => s.op.startsWith("rpc:"));
  const allOk = samples.filter((s) => s.ok);

  const report = {
    runId: RUN_TAG,
    supabaseUrl: cfg.SUPABASE_URL,
    usersRequested: USER_COUNT,
    usersActive: usedIds.size,
    rooms: rooms.length,
    durationSec: DURATION_SEC,
    setupMs: Math.round(setupMs),
    playMs: Math.round(playMs),
    totalRequests: samples.length,
    overallSuccessRate: samples.length
      ? (allOk.length / samples.length) * 100
      : 0,
    edgeFunction: summarize("edge:game-action:*", edgeSamples),
    rpc: summarize("rpc:*", rpcSamples),
    byOperation: summaries,
    topErrors: Object.entries(errors)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15)
      .map(([k, v]) => ({ error: k, count: v })),
  };

  console.log("\n========== LOAD TEST REPORT ==========");
  console.log(`Setup time: ${Math.round(setupMs)} ms`);
  console.log(`Play window: ${Math.round(playMs)} ms (${DURATION_SEC}s target)`);
  console.log(`Total API calls: ${samples.length}`);
  console.log(`Overall success rate: ${report.overallSuccessRate.toFixed(1)}%`);
  console.log(
    `\nEdge game-action latency (ms): p50=${report.edgeFunction.latencyMs.p50.toFixed(0)} p95=${report.edgeFunction.latencyMs.p95.toFixed(0)} p99=${report.edgeFunction.latencyMs.p99.toFixed(0)} max=${report.edgeFunction.latencyMs.max.toFixed(0)}`,
  );
  console.log(
    `RPC latency (ms): p50=${report.rpc.latencyMs.p50.toFixed(0)} p95=${report.rpc.latencyMs.p95.toFixed(0)} p99=${report.rpc.latencyMs.p99.toFixed(0)} max=${report.rpc.latencyMs.max.toFixed(0)}`,
  );

  console.log("\nPer-operation breakdown:");
  for (const s of summaries) {
    if (s.total < 5) continue;
    console.log(
      `  ${s.op}: ${s.success}/${s.total} ok (${s.successRate.toFixed(1)}%) | p50=${s.latencyMs.p50.toFixed(0)} p95=${s.latencyMs.p95.toFixed(0)} ms`,
    );
  }

  if (report.topErrors.length > 0) {
    console.log("\nTop errors:");
    for (const e of report.topErrors) {
      console.log(`  ${e.count}x ${e.error}`);
    }
  }

  const outPath = `scripts/load-test-results-${RUN_TAG}.json`;
  await Deno.writeTextFile(outPath, JSON.stringify(report, null, 2));
  console.log(`\nFull JSON report: ${outPath}`);

  if (Deno.env.get("LOAD_TEST_SKIP_CLEANUP") !== "1") {
    await cleanup(cfg, serviceKey, users);
  } else {
    console.log("\nSkipping cleanup (LOAD_TEST_SKIP_CLEANUP=1).");
  }

  const failureRate = 100 - report.overallSuccessRate;
  if (failureRate > 5) {
    console.error(`\nLoad test finished with elevated failure rate: ${failureRate.toFixed(1)}%`);
    Deno.exit(1);
  }
}

main().catch((e) => {
  console.error("\nLoad test failed:", e);
  Deno.exit(1);
});
