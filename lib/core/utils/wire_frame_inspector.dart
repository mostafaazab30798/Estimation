// W1.2 — Detect real opponent card faces in wire/public JSON payloads.

const _dummyRank = 'two';
const _dummySuit = 'spade';

/// True when [card] looks like a real face card (not the standard mask).
bool isMaskedWireCard(Map<String, dynamic> card) {
  final rank = card['rank']?.toString();
  final suit = card['suit']?.toString();
  return rank == _dummyRank && suit == _dummySuit;
}

/// Scans [payload] for opponent hand cards that are not masked dummies.
/// Returns leaked `{playerId, suit, rank}` entries (empty = pass).
List<Map<String, String>> findOpponentHandLeaks({
  required Map<String, dynamic> payload,
  required String viewerPlayerId,
}) {
  final leaks = <Map<String, String>>[];
  final players = payload['players'];
  if (players is! List) return leaks;

  for (final raw in players) {
    if (raw is! Map) continue;
    final player = Map<String, dynamic>.from(raw);
    final playerId = player['id']?.toString() ?? '';
    if (playerId.isEmpty || playerId == viewerPlayerId) continue;

    final hand = player['hand'];
    if (hand is! List) continue;

    for (final cardRaw in hand) {
      if (cardRaw is! Map) continue;
      final card = Map<String, dynamic>.from(cardRaw);
      if (!isMaskedWireCard(card)) {
        leaks.add({
          'playerId': playerId,
          'suit': card['suit']?.toString() ?? '',
          'rank': card['rank']?.toString() ?? '',
        });
      }
    }
  }

  if (payload.containsKey('deck') && payload['deck'] is List) {
    final deck = payload['deck'] as List;
    if (deck.isNotEmpty) {
      leaks.add({
        'playerId': '__deck__',
        'suit': 'deck',
        'rank': '${deck.length}',
      });
    }
  }

  return leaks;
}
