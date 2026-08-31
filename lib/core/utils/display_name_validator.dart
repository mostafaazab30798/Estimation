// lib/core/utils/display_name_validator.dart

/// Client-side display-name rules mirrored by the Supabase username trigger.
class DisplayNameValidator {
  static const int minLength = 2;
  static const int maxLength = 20;

  static final RegExp _allowedPattern = RegExp(
    r"^[\u0600-\u06FFa-zA-Z0-9 _.'\-]+$",
  );

  static const List<String> _blockedTerms = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'nigger',
    'nazi',
    'porn',
    'sex',
    'كسم',
    'شرموط',
    'عرص',
    'زب',
    'طيز',
  ];

  static String? validate(String raw) {
    final name = raw.trim();
    if (name.length < minLength) {
      return 'الاسم قصير جداً (الحد الأدنى $minLength أحرف).';
    }
    if (name.length > maxLength) {
      return 'الاسم طويل جداً (الحد الأقصى $maxLength حرفاً).';
    }
    if (!_allowedPattern.hasMatch(name)) {
      return 'يُسمح بالحروف والأرقام والمسافات فقط.';
    }
    final lowered = name.toLowerCase();
    for (final term in _blockedTerms) {
      if (lowered.contains(term)) {
        return 'هذا الاسم غير مسموح به.';
      }
    }
    return null;
  }
}
