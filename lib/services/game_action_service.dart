// Server-authoritative game actions via Edge Function (W1.1).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Routes player actions through the trusted `game-action` Edge Function
/// instead of host Realtime broadcast when [useServerAuthority] is enabled.
class GameActionService {
  GameActionService._();

  static const _uuid = Uuid();
  static bool useServerAuthority = false;

  static SupabaseClient get _client => Supabase.instance.client;

  /// Submit an action bound to the authenticated user (playerId ignored server-side).
  static Future<GameActionResult> submit({
    required String roomId,
    required String action,
    Map<String, dynamic> payload = const {},
    int? expectedSeq,
    String? actionId,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return GameActionResult.failure('NOT_AUTHENTICATED');
    }

    final body = {
      'roomId': roomId,
      'action': action,
      'payload': payload,
      'actionId': actionId ?? _uuid.v4(),
      if (expectedSeq != null) 'expectedSeq': expectedSeq,
    };

    try {
      final response = await _client.functions.invoke(
        'game-action',
        body: body,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status >= 400) {
        final err = _parseError(response.data);
        debugPrint('[GameActionService] $action failed: $err (${response.status})');
        return GameActionResult.failure(err, statusCode: response.status);
      }

      final data = _asMap(response.data);
      return GameActionResult.success(data);
    } on FunctionException catch (e) {
      final error = _parseError(e.details);
      debugPrint(
        '[GameActionService] $action rejected: $error (${e.status})',
      );
      return GameActionResult.failure(error, statusCode: e.status);
    } catch (e, st) {
      debugPrint('[GameActionService] invoke error: $e\n$st');
      return GameActionResult.failure('INVOKE_FAILED');
    }
  }

  static String _parseError(dynamic data) {
    final map = _asMap(data);
    return map['error']?.toString() ?? 'UNKNOWN_ERROR';
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return {};
  }
}

class GameActionResult {
  final bool ok;
  final String? error;
  final int? statusCode;
  final Map<String, dynamic> data;

  const GameActionResult._({
    required this.ok,
    this.error,
    this.statusCode,
    this.data = const {},
  });

  factory GameActionResult.success(Map<String, dynamic> data) =>
      GameActionResult._(ok: true, data: data);

  factory GameActionResult.failure(String error, {int? statusCode}) =>
      GameActionResult._(ok: false, error: error, statusCode: statusCode);

  int? get seq {
    final raw = data['seq'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  Map<String, dynamic>? get publicState {
    final raw = data['publicState'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  List<Map<String, dynamic>>? get privateHand {
    final raw = data['privateHand'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((card) => Map<String, dynamic>.from(card))
        .toList();
  }

  bool get idempotent => data['idempotent'] == true;
  bool get ephemeral => data['status'] == 'ephemeral';
}
