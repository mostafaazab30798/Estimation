// lib/core/models/bid.dart
import '../constants.dart';

class Bid {
  final int trickCount; // 1–13
  final Suit trumpSuit;

  const Bid({required this.trickCount, required this.trumpSuit});

  /// Returns true if this bid beats [other].
  /// Spec §5.4: B beats H if B.trickCount > H.trickCount
  ///             OR (B.trickCount == H.trickCount AND B.trumpSuit.priority > H.trumpSuit.priority)
  bool beats(Bid other) {
    if (trickCount > other.trickCount) return true;
    if (trickCount == other.trickCount &&
        trumpSuit.priority > other.trumpSuit.priority) {
      return true;
    }
    return false;
  }

  String get arabicLabel => '$trickCount ${trumpSuit.arabicName}';

  Map<String, dynamic> toJson() => {
        'trickCount': trickCount,
        'trumpSuit': trumpSuit.name,
      };

  factory Bid.fromJson(Map<String, dynamic> json) => Bid(
        trickCount: json['trickCount'] as int,
        trumpSuit: Suit.fromString(json['trumpSuit'] as String),
      );

  @override
  String toString() => '$trickCount ${trumpSuit.label}';
}

