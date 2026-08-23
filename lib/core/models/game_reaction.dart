// lib/core/models/game_reaction.dart
//
// Model and catalog for in-game reactions (emojis, tactical Arabic phrases, and banter).

enum ReactionCategory {
  emojis,
  tactical,
  banter,
}

class ReactionPreset {
  final String id;
  final String emoji;
  final String? text;
  final ReactionCategory category;

  const ReactionPreset({
    required this.id,
    required this.emoji,
    this.text,
    required this.category,
  });

  String get displayText => text != null ? '$text $emoji'.trim() : emoji;
}

class GameReaction {
  final String id;
  final String playerId;
  final String? playerName;
  final String emoji;
  final String? text;
  final int timestamp;

  const GameReaction({
    required this.id,
    required this.playerId,
    this.playerName,
    required this.emoji,
    this.text,
    required this.timestamp,
  });

  String get displayText => text != null ? '$text $emoji'.trim() : emoji;

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'playerName': playerName,
        'emoji': emoji,
        'text': text,
        'timestamp': timestamp,
      };

  factory GameReaction.fromJson(Map<String, dynamic> json) => GameReaction(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        playerId: json['playerId'] as String? ?? '',
        playerName: json['playerName'] as String?,
        emoji: json['emoji'] as String? ?? '🔥',
        text: json['text'] as String?,
        timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );

  // ── Catalog Presets ──────────────────────────────────────────────────────

  static const List<ReactionPreset> emojis = [
    ReactionPreset(id: 'e_fire', emoji: '🔥', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_laugh', emoji: '😂', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_crown', emoji: '👑', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_clap', emoji: '👏', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_skull', emoji: '💀', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_shush', emoji: '🤫', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_heartbreak', emoji: '💔', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_target', emoji: '🎯', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_bomb', emoji: '💣', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_coffee', emoji: '☕', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_zap', emoji: '⚡', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_cold', emoji: '🥶', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_dice', emoji: '🎲', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_rocket', emoji: '🚀', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_lion', emoji: '🦁', category: ReactionCategory.emojis),
    ReactionPreset(id: 'e_facepalm', emoji: '🤦‍♂️', category: ReactionCategory.emojis),
  ];

  static const List<ReactionPreset> tactical = [
    ReactionPreset(id: 't_exact_call', emoji: '🎯', text: 'كول مظبوط!', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_pro_player', emoji: '🔥', text: 'يا لعيب!', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_great_move', emoji: '👏', text: 'جامدة دي!', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_i_am_king', emoji: '👑', text: 'أنا الملك', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_bravo_champ', emoji: '🦁', text: 'عاش يا بطل!', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_remontada', emoji: '🚀', text: 'الريمونتادا قادمة!', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_calc_right', emoji: '🧠', text: 'حسبتها صح', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_play_smart', emoji: '💡', text: 'العب بذكاء', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_calculated', emoji: '📊', text: 'كول محسوب', category: ReactionCategory.tactical),
    ReactionPreset(id: 't_wont_take', emoji: '😉', text: 'مش هتاخدها', category: ReactionCategory.tactical),
  ];

  static const List<ReactionPreset> banter = [
    ReactionPreset(id: 'b_hurry_up', emoji: '⏳', text: 'خلص يا غالي', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_lucky_shot', emoji: '🎲', text: 'ضربة حظ', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_who_said', emoji: '😏', text: 'مين قال هتكسب؟', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_lost_it', emoji: '💀', text: 'راحت عليك!', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_dont_cheer', emoji: '😂', text: 'متفرحش أوي', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_swept_all', emoji: '🌪️', text: 'كوشت على كله!', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_hard_luck', emoji: '💔', text: 'معلش تعيش وتاخد غيرها', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_oh_lord', emoji: '😱', text: 'يا ساتر يا رب', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_chill_out', emoji: '☕', text: 'سلامتك يا حبيب', category: ReactionCategory.banter),
    ReactionPreset(id: 'b_play_fast', emoji: '⚡', text: 'العب بسرعة', category: ReactionCategory.banter),
  ];

  static List<ReactionPreset> get allPresets => [...emojis, ...tactical, ...banter];
}
