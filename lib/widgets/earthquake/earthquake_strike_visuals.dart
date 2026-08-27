// Tiny shared registry so TrickArea can skip its slide-in intro when a card
// arrives via Earthquake Strike (the flying overlay already delivered it).

class EarthquakeStrikeVisuals {
  EarthquakeStrikeVisuals._();

  static final Map<String, DateTime> _skipUntil = {};

  static void markSkipIntro(String cardId) {
    _skipUntil[cardId] = DateTime.now().add(const Duration(seconds: 2));
    // Opportunistic cleanup of expired entries
    if (_skipUntil.length > 16) {
      final now = DateTime.now();
      _skipUntil.removeWhere((_, until) => now.isAfter(until));
    }
  }

  static bool shouldSkipIntro(String cardId) {
    final until = _skipUntil[cardId];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _skipUntil.remove(cardId);
      return false;
    }
    return true;
  }
}
