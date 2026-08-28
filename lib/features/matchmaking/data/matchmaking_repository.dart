import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../lobby/domain/models/game_room.dart';
import '../domain/models/bot_fill_vote_result.dart';
import '../domain/models/matchmaking_join_result.dart';

class MatchmakingRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> _ensureAuth() async {
    if (_client.auth.currentUser == null) {
      await _client.auth
          .signInAnonymously()
          .timeout(const Duration(seconds: 8));
    }
    if (_client.auth.currentUser == null) {
      throw Exception('MATCHMAKING_NOT_AUTHENTICATED');
    }
  }

  Future<MatchmakingJoinResult> enterMatchmaking({
    required String playerName,
    required String gameType,
    required int totalRounds,
  }) async {
    await _ensureAuth();
    final response = await _client.rpc('enter_matchmaking', params: {
      'p_player_name': playerName,
      'p_game_type': gameType,
      'p_total_rounds': totalRounds,
    });
    return MatchmakingJoinResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<GameRoom> getRoom(String roomId) async {
    final response =
        await _client.from('game_rooms').select().eq('id', roomId).single();
    return GameRoom.fromJson(response);
  }

  Future<void> leaveMatchmaking(String roomId) async {
    await _client.rpc('leave_matchmaking', params: {'p_room_id': roomId});
  }

  Future<void> startApprovedMatch(String roomId) async {
    await _client.rpc(
      'start_matchmaking_room',
      params: {'p_room_id': roomId},
    );
  }

  Future<BotFillOfferResult?> openBotFillOffer(String roomId) async {
    try {
      final response = await _client.rpc(
        'open_bot_fill_offer',
        params: {'p_room_id': roomId},
      );
      if (response == null) return null;
      return BotFillOfferResult.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (error) {
      debugPrint('[Matchmaking] Open offer failed: $error');
      rethrow;
    }
  }

  Future<BotFillVoteResult> castBotFillVote({
    required String roomId,
    required int offerVersion,
    required bool accepted,
  }) async {
    final response = await _client.rpc('cast_bot_fill_vote', params: {
      'p_room_id': roomId,
      'p_offer_version': offerVersion,
      'p_accepted': accepted,
    });
    return BotFillVoteResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  String translateError(Object error) {
    final raw = error.toString();
    debugPrint('[Matchmaking] $raw');
    if (raw.contains('MATCHMAKING_NOT_AUTHENTICATED')) {
      return 'تعذر بدء البحث. حاول تسجيل الدخول مرة أخرى.';
    }
    if (raw.contains('MATCHMAKING_ROOM_INVALID')) {
      return 'انتهت جلسة البحث. سنعيدك للصفحة الرئيسية.';
    }
    if (raw.contains('MATCHMAKING_ALREADY_STARTING')) {
      return 'المباراة بدأت بالفعل.';
    }
    if (raw.contains('MATCHMAKING_STALE_OFFER')) {
      return 'انتهى هذا الاختيار لأن عدد اللاعبين تغيّر.';
    }
    if (raw.contains('ONGOING_GAME_REQUIRES_RETURN')) {
      return 'لديك مباراة ما زالت جارية. عد إليها قبل بدء طابور جديد.';
    }
    return 'تعذر الاتصال بخدمة البحث عن لاعبين. تحقق من الإنترنت وحاول مجدداً.';
  }
}
