// lib/core/models/card.dart
import '../constants.dart';

class PlayingCard {
  final Suit suit;
  final Rank rank;

  const PlayingCard({required this.suit, required this.rank});

  /// Sort key for auto-sort: primary = suit priority descending,
  /// secondary = rank sort index descending (A first).
  /// Lower key = displayed first (leftmost in hand).
  ///
  /// Spec §4: Group by suit (Spade→Heart→Diamond→Club), within suit A→2.
  int get sortKey {
    // Suit: Spade priority=3 (displayed first) → Club priority=0 (last)
    // We want high priority first, so invert: (3 - suit.priority)
    final suitOrder = 3 - suit.priority; // 0=Spade, 1=Heart, 2=Diamond, 3=Club
    // Rank: Ace sortIndex=12 (displayed first) → Two=0 (last)
    // We want high rank first, so invert: (12 - rank.sortIndex)
    final rankOrder = 12 - rank.sortIndex;
    return suitOrder * 100 + rankOrder;
  }

  String get id => '${suit.name}_${rank.name}';

  Map<String, dynamic> toJson() => {
        'suit': suit.name,
        'rank': rank.name,
      };

  factory PlayingCard.fromJson(Map<String, dynamic> json) => PlayingCard(
        suit: Suit.fromString(json['suit'] as String),
        rank: Rank.fromString(json['rank'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => '${rank.label}${suit.label}';

  /// Build the complete 52-card deck
  static List<PlayingCard> fullDeck() {
    return [
      for (final suit in Suit.values)
        for (final rank in Rank.values) PlayingCard(suit: suit, rank: rank),
    ];
  }
}

class TrickCard {
  final String playerId;
  final PlayingCard card;

  const TrickCard({required this.playerId, required this.card});

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'card': card.toJson(),
      };

  factory TrickCard.fromJson(Map<String, dynamic> json) => TrickCard(
        playerId: json['playerId'] as String,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
      );
}

