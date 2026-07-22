// lib/networking/messages.dart
//
// JSON message protocol between host server and clients.

import 'dart:convert';

enum MessageType {
  // Server → Clients
  stateUpdate,    // full game state broadcast
  playerJoined,   // new player joined the lobby
  error,
  // Client → Server
  playerAction,   // any game action from a player
  joinRequest,    // client wants to join
  heartbeat,
}

class GameMessage {
  final MessageType type;
  final Map<String, dynamic> payload;

  const GameMessage({required this.type, required this.payload});

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
      };

  String toJsonString() => jsonEncode(toJson());

  factory GameMessage.fromJson(Map<String, dynamic> json) => GameMessage(
        type: MessageType.values.firstWhere(
            (e) => e.name == json['type']),
        payload: json['payload'] as Map<String, dynamic>,
      );

  factory GameMessage.fromJsonString(String s) =>
      GameMessage.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

// ── Action payloads ──────────────────────────────────────────────────────────

class ActionType {
  static const String submitBid = 'submitBid';
  static const String passBid = 'passBid';

  static const String approveRedeal = 'approveRedeal';
  static const String rejectRedeal = 'rejectRedeal';
  static const String confirmNoVoid = 'confirmNoVoid';  // no void, ready
  static const String unready = 'unready';              // cancel ready state
  static const String submitDeclaration = 'submitDeclaration';
  static const String playCard = 'playCard';
  static const String startGame = 'startGame';          // host starts
  static const String nextRound = 'nextRound';
  static const String changeTheme = 'changeTheme';      // host changes card theme
  static const String requestStateSync = 'requestStateSync'; // client requests immediate full state broadcast
}


