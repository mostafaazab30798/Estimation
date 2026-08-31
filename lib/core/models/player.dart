// lib/core/models/player.dart
import 'card.dart';
import '../../services/profile_service.dart';

class Player {
  final String id;
  String name;
  final int seatIndex; // 0–3
  final String? photo; // user's selected profile picture

  List<PlayingCard> hand;
  List<List<TrickCard>> takenTricks;

  // Per-round state
  int? declared; // tricks declared (null before declaration phase)
  int actual;    // tricks won so far this round
  bool hasPassed; // passed in auction?
  bool isDashCall; // declared Dash Call (0 tricks blind) before auction
  bool isRisk;     // last player took risk (sum <= 11 in under)
  int totalScore; // cumulative across rounds

  Player({
    required this.id,
    required this.name,
    required this.seatIndex,
    this.photo,
    List<PlayingCard>? hand,
    List<List<TrickCard>>? takenTricks,
    this.declared,
    this.actual = 0,
    this.hasPassed = false,
    this.isDashCall = false,
    this.isRisk = false,
    this.totalScore = 0,
  })  : hand = hand ?? [],
        takenTricks = takenTricks ?? [];

  void resetForRound() {
    hand = [];
    takenTricks = [];
    declared = null;
    actual = 0;
    hasPassed = false;
    isDashCall = false;
    isRisk = false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seatIndex': seatIndex,
        'photo': photo,
        'hand': hand.map((c) => c.toJson()).toList(),
        'takenTricks': takenTricks
            .map((trick) => trick.map((tc) => tc.toJson()).toList())
            .toList(),
        'declared': declared,
        'actual': actual,
        'hasPassed': hasPassed,
        'isDashCall': isDashCall,
        'isRisk': isRisk,
        'totalScore': totalScore,
      };

  /// Serializes player data. When [isSelf] is false, private hand cards are
  /// masked to prevent opponents from reading secret cards over network broadcasts.
  Map<String, dynamic> toSanitizedJson({bool isSelf = true}) => {
        'id': id,
        'name': name,
        'seatIndex': seatIndex,
        'photo': isSelf ? photo : ProfileService.publicAvatarRef(photo),
        'hand': isSelf
            ? hand.map((c) => c.toJson()).toList()
            : List.generate(
                hand.length,
                (_) => {'suit': 'spade', 'rank': 'two'},
              ),
        'takenTricks': takenTricks
            .map((trick) => trick.map((tc) => tc.toJson()).toList())
            .toList(),
        'declared': declared,
        'actual': actual,
        'hasPassed': hasPassed,
        'isDashCall': isDashCall,
        'isRisk': isRisk,
        'totalScore': totalScore,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final p = Player(
      id: json['id'] as String,
      name: json['name'] as String,
      seatIndex: json['seatIndex'] as int,
      photo: json['photo'] as String?,
      declared: json['declared'] as int?,
      actual: json['actual'] as int,
      hasPassed: json['hasPassed'] as bool? ?? false,
      isDashCall: json['isDashCall'] as bool? ?? false,
      isRisk: json['isRisk'] as bool? ?? false,
      totalScore: json['totalScore'] as int? ?? 0,
    );
    p.hand = (json['hand'] as List<dynamic>?)
            ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
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
    String? photo,
    List<PlayingCard>? hand,
    List<List<TrickCard>>? takenTricks,
    int? declared,
    int? actual,
    bool? hasPassed,
    bool? isDashCall,
    bool? isRisk,
    int? totalScore,
  }) {
    final p = Player(
      id: id ?? this.id,
      name: name ?? this.name,
      seatIndex: seatIndex ?? this.seatIndex,
      photo: photo ?? this.photo,
      declared: declared ?? this.declared,
      actual: actual ?? this.actual,
      hasPassed: hasPassed ?? this.hasPassed,
      isDashCall: isDashCall ?? this.isDashCall,
      isRisk: isRisk ?? this.isRisk,
      totalScore: totalScore ?? this.totalScore,
    );
    p.hand = hand ?? List.from(this.hand);
    p.takenTricks = takenTricks ?? List.from(this.takenTricks);
    return p;
  }
}
