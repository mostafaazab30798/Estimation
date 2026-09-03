// lib/services/session_storage_service.dart
//
// Persists the player's active room session to SharedPreferences.
//
// A session is written the instant a player successfully creates or joins a
// room, and cleared ONLY when:
//   • The match formally ends (GameProvider.reset() after matchEnd).
//   • The player explicitly forfeits / leaves (GameProvider.reset()).
//   • ReconnectionManager determines the room is expired / no longer valid.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── DTO ───────────────────────────────────────────────────────────────────────

/// Lightweight snapshot of the data needed to reconnect to an in-progress room.
class ActiveRoomSession {
  final String roomId;
  final String roomCode;
  final String playerId;
  final String playerName;
  final bool isHost;

  const ActiveRoomSession({
    required this.roomId,
    required this.roomCode,
    required this.playerId,
    required this.playerName,
    required this.isHost,
  });

  @override
  String toString() =>
      'ActiveRoomSession(room: $roomCode, player: $playerName, isHost: $isHost)';
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Handles reading and writing the active room session to local storage.
///
/// All public methods are safe to call from any isolate; failures are caught
/// and logged so they never crash the app.
class SessionStorageService {
  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const _kRoomId     = 'session_room_id';
  static const _kRoomCode   = 'session_room_code';
  static const _kPlayerId   = 'session_player_id';
  static const _kPlayerName = 'session_player_name';
  static const _kIsHost     = 'session_is_host';

  static ActiveRoomSession? _cachedSession;
  static bool _cacheLoaded = false;

  static void _invalidateCache() {
    _cacheLoaded = false;
    _cachedSession = null;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Persist all data required to recover an in-progress room session.
  ///
  /// Call this immediately after [hostGame] or [joinGameWithCode] succeeds.
  Future<void> saveActiveRoomSession({
    required String roomId,
    required String roomCode,
    required String playerId,
    required String playerName,
    required bool isHost,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_kRoomId,     roomId),
        prefs.setString(_kRoomCode,   roomCode),
        prefs.setString(_kPlayerId,   playerId),
        prefs.setString(_kPlayerName, playerName),
        prefs.setBool  (_kIsHost,     isHost),
      ]);
      _cachedSession = ActiveRoomSession(
        roomId: roomId,
        roomCode: roomCode,
        playerId: playerId,
        playerName: playerName,
        isHost: isHost,
      );
      _cacheLoaded = true;
      debugPrint('[Session] ✓ saved  room=$roomCode  isHost=$isHost');
    } catch (e) {
      // Non-fatal: if SharedPreferences is unavailable the player simply won't
      // get the auto-reconnect flow on the next cold start.
      debugPrint('[Session] ✗ save failed: $e');
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Return the last saved session, or null if none exists / data is corrupt.
  Future<ActiveRoomSession?> getActiveRoomSession() async {
    if (_cacheLoaded) return _cachedSession;
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomId     = prefs.getString(_kRoomId);
      final roomCode   = prefs.getString(_kRoomCode);
      final playerId   = prefs.getString(_kPlayerId);
      final playerName = prefs.getString(_kPlayerName);
      final isHost     = prefs.getBool(_kIsHost);

      // All five fields must be present; partial data is treated as no session.
      if (roomId == null || roomCode == null ||
          playerId == null || playerName == null || isHost == null) {
        _cacheLoaded = true;
        _cachedSession = null;
        return null;
      }

      _cachedSession = ActiveRoomSession(
        roomId:     roomId,
        roomCode:   roomCode,
        playerId:   playerId,
        playerName: playerName,
        isHost:     isHost,
      );
      _cacheLoaded = true;
      return _cachedSession;
    } catch (e) {
      debugPrint('[Session] ✗ load failed: $e');
      return null;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Remove all persisted session data.
  ///
  /// Call this when the player explicitly leaves, the match ends, or recovery
  /// determines the room is no longer valid.
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kRoomId),
        prefs.remove(_kRoomCode),
        prefs.remove(_kPlayerId),
        prefs.remove(_kPlayerName),
        prefs.remove(_kIsHost),
      ]);
      _invalidateCache();
      debugPrint('[Session] ✓ cleared');
    } catch (e) {
      debugPrint('[Session] ✗ clear failed: $e');
    }
  }

  // ── Update host flag ──────────────────────────────────────────────────────

  /// Update the isHost flag in the persisted session (used after host promotion).
  Future<void> updateIsHost({required bool isHost}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsHost, isHost);
      if (_cachedSession != null) {
        _cachedSession = ActiveRoomSession(
          roomId: _cachedSession!.roomId,
          roomCode: _cachedSession!.roomCode,
          playerId: _cachedSession!.playerId,
          playerName: _cachedSession!.playerName,
          isHost: isHost,
        );
      }
      debugPrint('[Session] ✓ isHost updated → $isHost');
    } catch (e) {
      debugPrint('[Session] ✗ isHost update failed: $e');
    }
  }
}
