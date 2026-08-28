// lib/modes/basra/domain/basra_constants.dart

/// Match ends when any player reaches this cumulative score.
const int kBasraMatchTarget = 121;

/// Cards dealt to each player at the start of a round and after hands empty.
const int kBasraHandSize = 4;

/// Face-up cards dealt to the table at round start.
const int kBasraTableSize = 4;

/// Card-count threshold for the majority bonus.
const int kBasraMajorityThreshold = 27;

/// Points awarded to the player who captured 27+ cards.
const int kBasraMajorityPoints = 30;

/// Bonus points for each Basra.
const int kBasraBasraBonus = 10;

/// Points for each captured Jack.
const int kBasraJackPoints = 1;

/// Points for each captured Ace.
const int kBasraAcePoints = 1;

/// Bonus for capturing the 2 of Spades.
const int kBasraTwoOfSpadesPoints = 2;

/// Bonus for capturing the 10 of Diamonds.
const int kBasraTenOfDiamondsPoints = 3;

/// Supported player counts. Remaining cards after the initial deal divide
/// evenly for 2, 3 and 4 players with a 52-card deck.
const List<int> kBasraSupportedPlayerCounts = [2, 3, 4];
