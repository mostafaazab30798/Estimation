// Mirrors public.sanitize_game_state_json — strip real hands/deck before broadcast.

type Card = { suit: string; rank: string };

function maskHand(hand: unknown[]): Card[] {
  return hand.map(() => ({ suit: "spade", rank: "two" }));
}

/** Strip opponent hands and hidden deck from a public state snapshot. */
export function sanitizePublicState(
  state: Record<string, unknown>,
): Record<string, unknown> {
  const result = { ...state };
  const players = result.players;

  if (Array.isArray(players)) {
    result.players = players.map((raw) => {
      const player = { ...(raw as Record<string, unknown>) };
      const hand = player.hand;
      if (Array.isArray(hand) && hand.length > 0) {
        player.hand = maskHand(hand);
      }
      return player;
    });
  }

  if (Array.isArray(result.deck)) {
    result.deckCount = result.deck.length;
    delete result.deck;
  }

  return result;
}
