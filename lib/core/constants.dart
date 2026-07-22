// lib/core/constants.dart

/// Suit priority (higher index = higher priority in bids and sorting)
/// Spade > Heart > Diamond > Club
enum Suit {
  club(label: '♣', arabicName: 'تريفل', priority: 0, color: SuitColor.black),
  diamond(label: '♦', arabicName: 'كارو', priority: 1, color: SuitColor.red),
  heart(label: '♥', arabicName: 'هارت', priority: 2, color: SuitColor.red),
  spade(label: '♠', arabicName: 'سبيد', priority: 3, color: SuitColor.black);

  const Suit({
    required this.label,
    required this.arabicName,
    required this.priority,
    required this.color,
  });

  final String label;
  final String arabicName;
  final int priority; // higher = stronger
  final SuitColor color;

  static Suit fromString(String s) =>
      Suit.values.firstWhere((e) => e.name == s);
}

enum SuitColor { red, black }

/// Card rank (higher index = higher rank)
/// A > K > Q > J > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2
enum Rank {
  two(label: '2', arabicLabel: '٢', sortIndex: 0),
  three(label: '3', arabicLabel: '٣', sortIndex: 1),
  four(label: '4', arabicLabel: '٤', sortIndex: 2),
  five(label: '5', arabicLabel: '٥', sortIndex: 3),
  six(label: '6', arabicLabel: '٦', sortIndex: 4),
  seven(label: '7', arabicLabel: '٧', sortIndex: 5),
  eight(label: '8', arabicLabel: '٨', sortIndex: 6),
  nine(label: '9', arabicLabel: '٩', sortIndex: 7),
  ten(label: '10', arabicLabel: '١٠', sortIndex: 8),
  jack(label: 'J', arabicLabel: 'J', sortIndex: 9),
  queen(label: 'Q', arabicLabel: 'Q', sortIndex: 10),
  king(label: 'K', arabicLabel: 'K', sortIndex: 11),
  ace(label: 'A', arabicLabel: 'A', sortIndex: 12);

  const Rank({
    required this.label,
    required this.arabicLabel,
    required this.sortIndex,
  });

  final String label;
  final String arabicLabel;
  final int sortIndex; // higher = stronger

  static Rank fromString(String s) =>
      Rank.values.firstWhere((e) => e.name == s);
}

/// Match ends when a player reaches this score
const int kMatchEndScore = 50;

/// Bonus added to The Bidder's score when they meet their declaration
const int kBidderBonus = 10;

/// Number of players in the game
const int kPlayerCount = 4;

/// Number of tricks per round
const int kTricksPerRound = 13;

