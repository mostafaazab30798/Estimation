// lib/core/utils/string_utils.dart

class StringUtils {
  /// Formats a string so the first letter of each word/name is capitalized (Title Case).
  /// Handles whitespace, hyphens, and mixed casing cleanly.
  /// Examples:
  /// - "john doe" -> "John Doe"
  /// - "JOHN DOE" -> "John Doe"
  /// - "jean-paul" -> "Jean-Paul"
  /// - "mostafa azab" -> "Mostafa Azab"
  /// - "أحمد علي" -> "أحمد علي" (Arabic characters are unaffected)
  static String capitalizeWords(String? input) {
    if (input == null) return '';
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word
              .split('-')
              .map((part) => part.isEmpty
                  ? part
                  : part[0].toUpperCase() +
                      (part.length > 1 ? part.substring(1).toLowerCase() : ''))
              .join('-');
        })
        .join(' ');
  }
}
