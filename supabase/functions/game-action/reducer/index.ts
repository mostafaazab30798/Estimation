// Reducer router — Estimation, 99, and Basra.

import { reduceBasra } from "./basra.ts";
import { reduceEstimation } from "./estimation.ts";
import { reduceNinetyNine } from "./ninety_nine.ts";
import { ReduceInput, ReduceResult, errResult } from "./types.ts";

const ESTIMATION_TYPES = new Set(["kotchina", "estimation"]);

export function reduceGameAction(input: ReduceInput): ReduceResult {
  const gameType = input.ctx.gameType?.toLowerCase() ?? "kotchina";

  if (ESTIMATION_TYPES.has(gameType)) {
    return reduceEstimation(input);
  }

  if (gameType === "ninety_nine" || gameType === "99") {
    return reduceNinetyNine(input);
  }

  if (gameType === "basra") {
    return reduceBasra(input);
  }

  return errResult(`UNKNOWN_GAME_TYPE: ${gameType}`);
}
