// Shared timing for the Earthquake Card Strike flight + impact.

class EarthquakeTiming {
  EarthquakeTiming._();

  /// Full hand → air → table flight duration.
  static const Duration flightDuration = Duration(milliseconds: 780);

  /// Fraction of [flightDuration] when the card hits the table.
  static const double impactFraction = 0.68;

  /// Delay from strike start until table impact (playCard + shake).
  static Duration get impactDelay => Duration(
        milliseconds: (flightDuration.inMilliseconds * impactFraction).round(),
      );

  /// Screen shake after impact.
  static const Duration shakeDuration = Duration(milliseconds: 900);

  /// Crack / debris overlay after impact.
  static const Duration crackDuration = Duration(milliseconds: 1200);
}
