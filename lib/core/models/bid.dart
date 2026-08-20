// lib/core/models/bid.dart
import '../constants.dart';

class Bid {
  final int trickCount; // 4–13
  final Trump trump;

  const Bid({required this.trickCount, required this.trump});

  /// Backward-compat getter: returns Trump.suit if not sans
  Suit? get suit => trump.suit;
  Trump get trumpSuit => trump; // for backward compatibility

  /// Returns true if this bid beats [other].
  /// B beats H if B.trickCount > H.trickCount
  ///             OR (B.trickCount == H.trickCount AND B.trump.priority > H.trump.priority)
  bool beats(Bid other) {
    if (trickCount > other.trickCount) return true;
    if (trickCount == other.trickCount &&
        trump.priority > other.trump.priority) {
      return true;
    }
    return false;
  }

  String get arabicLabel => '$trickCount ${trump.arabicName}';

  Map<String, dynamic> toJson() => {
        'trickCount': trickCount,
        'trump': trump.name,
        'trumpSuit': trump.name,
      };

  factory Bid.fromJson(Map<String, dynamic> json) {
    final trumpName = (json['trump'] ?? json['trumpSuit']) as String;
    return Bid(
      trickCount: json['trickCount'] as int,
      trump: Trump.fromString(trumpName),
    );
  }

  @override
  String toString() => '$trickCount ${trump.label}';
}
