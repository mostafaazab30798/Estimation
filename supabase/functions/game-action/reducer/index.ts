// Reducer router — Estimation first; 99 / Basra stubbed for follow-up PRs.

import { reduceEstimation } from "./estimation.ts";
import { ReduceInput, ReduceResult, errResult } from "./types.ts";

const ESTIMATION_TYPES = new Set(["kotchina", "estimation"]);

export function reduceGameAction(input: ReduceInput): ReduceResult {
  const gameType = input.ctx.gameType?.toLowerCase() ?? "kotchina";

  if (ESTIMATION_TYPES.has(gameType)) {
    return reduceEstimation(input);
  }

  if (gameType === "ninety_nine" || gameType === "99") {
    return errResult("MODE_NOT_IMPLEMENTED: ninety_nine");
  }

  if (gameType === "basra") {
    return errResult("MODE_NOT_IMPLEMENTED: basra");
  }

  return errResult(`UNKNOWN_GAME_TYPE: ${gameType}`);
}
