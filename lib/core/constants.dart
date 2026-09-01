// lib/core/constants.dart

/// User-facing app name shown on the home screen, about, and share branding.
const String kAppName = 'سهرة ورق';

/// Fallback display name when the player has not set a username.
const String kDefaultPlayerName = 'لاعب سهرة ورق';

/// Asset path for the app logo and launcher artwork.
const String kAppLogoAsset = 'assets/logo.png';

/// Transparent login-hero artwork (same mark, no wallpaper).
const String kAppLoginArtAsset = 'assets/login.png';

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

enum SuitColor { red, black, gold }

/// Trump contract chosen in auction or fixed in last 5 rounds
/// Sans (No Trump) > Spade > Heart > Diamond > Club
enum Trump {
  club(
      label: '♣',
      arabicName: 'تريفل',
      priority: 0,
      color: SuitColor.black,
      suit: Suit.club),
  diamond(
      label: '♦',
      arabicName: 'كارو',
      priority: 1,
      color: SuitColor.red,
      suit: Suit.diamond),
  heart(
      label: '♥',
      arabicName: 'هارت',
      priority: 2,
      color: SuitColor.red,
      suit: Suit.heart),
  spade(
      label: '♠',
      arabicName: 'سبيد',
      priority: 3,
      color: SuitColor.black,
      suit: Suit.spade),
  sans(
      label: 'NT',
      arabicName: 'سانز',
      priority: 4,
      color: SuitColor.gold,
      suit: null);

  const Trump({
    required this.label,
    required this.arabicName,
    required this.priority,
    required this.color,
    required this.suit,
  });

  final String label;
  final String arabicName;
  final int priority; // higher = stronger
  final SuitColor color;
  final Suit? suit; // null for sans (no-trump)

  bool get isSans => this == Trump.sans;

  static Trump fromString(String s) =>
      Trump.values.firstWhere((e) => e.name == s, orElse: () => Trump.sans);

  static Trump fromSuit(Suit s) => Trump.values.firstWhere((e) => e.suit == s);
}

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

/// Standard official match total rounds (البولة الكاملة): 13 free + 5 fixed
const int kBoulaTotalRounds = 18;

/// Mini Estimation match: 5 free + 5 fixed trump rounds
const int kMiniTotalRounds = 10;

/// Number of championship fixed-trump rounds at the end of a Boula
const int kFixedTrumpRoundCount = 5;

/// Minimum bid trick count in auction
const int kMinBidTricks = 4;

/// Override bid trick count to change fixed trump in last 5 rounds
const int kOverrideFixedTrumpTricks = 8;

/// Whether [totalRounds] is a round-based Boula format (classic or mini).
bool isRoundBasedBoula(int totalRounds) =>
    totalRounds == kBoulaTotalRounds || totalRounds == kMiniTotalRounds;

/// Fixed trump for the last 5 rounds: Sans → Spade → Heart → Diamond → Club.
/// Classic: rounds 14–18. Mini: rounds 6–10.
Trump? fixedTrumpForRound(int roundNumber,
    [int totalRounds = kBoulaTotalRounds]) {
  if (!isRoundBasedBoula(totalRounds)) return null;
  final firstFixed = totalRounds - kFixedTrumpRoundCount + 1;
  if (roundNumber < firstFixed || roundNumber > totalRounds) return null;
  switch (roundNumber - firstFixed) {
    case 0:
      return Trump.sans;
    case 1:
      return Trump.spade;
    case 2:
      return Trump.heart;
    case 3:
      return Trump.diamond;
    case 4:
      return Trump.club;
    default:
      return null;
  }
}

/// Match ends when a player reaches this score (in points target mode)
const int kMatchEndScore = 50;

/// Bonus added to The Bidder's score when they meet their declaration
const int kBidderBonus = 10;

/// Number of players in the game
const int kPlayerCount = 4;

/// Number of tricks per round
const int kTricksPerRound = 13;

/// ── Turn Timing Constants (1 minute for all phases) ───────────
const Duration kAuctionTurnTimeout = Duration(seconds: 60);
const Duration kDeclarationTurnTimeout = Duration(seconds: 60);
const Duration kTrickTurnTimeout = Duration(seconds: 60);
const Duration kDashCallTurnTimeout = Duration(seconds: 60);
const int kTurnWarningThresholdSeconds = 5;

/// Bot plays for an absent human after this delay (seat still reclaimable).
const Duration kBotTakeoverDelay = Duration(seconds: 30);

/// Max absence before the player is detached and may not reclaim the same seat.
const Duration kAbsentPlayerDetachTimeout = Duration(minutes: 5);

/// Cooldown before a detached player may enter a new online matchmaking queue.
const Duration kOnlineGameBanDuration = Duration(minutes: 5);
