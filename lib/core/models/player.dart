// lib/core/models/player.dart
import 'card.dart';

class Player {
  final String id;
  String name;
  final int seatIndex; // 0–3

  List<PlayingCard> hand;
  List<List<TrickCard>> takenTricks;

  // Per-round state
  int? declared; // tricks declared (null before declaration phase)
  int actual;    // tricks won so far this round
  bool hasPassed; // passed in auction?
  int totalScore; // cumulative across rounds

  Player({
    required this.id,
    required this.name,
    required this.seatIndex,
    List<PlayingCard>? hand,
    List<List<TrickCard>>? takenTricks,
    this.declared,
    this.actual = 0,
    this.hasPassed = false,
    this.totalScore = 0,
  })  : hand = hand ?? [],
        takenTricks = takenTricks ?? [];

  void resetForRound() {
    hand = [];
    takenTricks = [];
    declared = null;
    actual = 0;
    hasPassed = false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seatIndex': seatIndex,
        'hand': hand.map((c) => c.toJson()).toList(),
        'takenTricks': takenTricks
            .map((trick) => trick.map((tc) => tc.toJson()).toList())
            .toList(),
        'declared': declared,
        'actual': actual,
        'hasPassed': hasPassed,
        'totalScore': totalScore,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final p = Player(
      id: json['id'] as String,
      name: json['name'] as String,
      seatIndex: json['seatIndex'] as int,
      declared: json['declared'] as int?,
      actual: json['actual'] as int,
      hasPassed: json['hasPassed'] as bool,
      totalScore: json['totalScore'] as int,
    );
    p.hand = (json['hand'] as List<dynamic>)
        .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
        .toList();
    if (json['takenTricks'] != null) {
      p.takenTricks = (json['takenTricks'] as List<dynamic>)
          .map((trick) => (trick as List<dynamic>)
              .map((tc) => TrickCard.fromJson(tc as Map<String, dynamic>))
              .toList())
          .toList();
    } else {
      p.takenTricks = [];
    }
    return p;
  }

  Player copyWith({
    String? id,
    String? name,
    int? seatIndex,
    List<PlayingCard>? hand,
    List<List<TrickCard>>? takenTricks,
    int? declared,
    int? actual,
    bool? hasPassed,
    int? totalScore,
  }) {
    final p = Player(
      id: id ?? this.id,
      name: name ?? this.name,
      seatIndex: seatIndex ?? this.seatIndex,
      declared: declared ?? this.declared,
      actual: actual ?? this.actual,
      hasPassed: hasPassed ?? this.hasPassed,
      totalScore: totalScore ?? this.totalScore,
    );
    p.hand = hand ?? List.from(this.hand);
    p.takenTricks = takenTricks ?? List.from(this.takenTricks);
    return p;
  }
}

