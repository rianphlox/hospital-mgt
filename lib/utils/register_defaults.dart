/// Register header values that are the same for every entry at this
/// hospital. Used to prefill the register form, to fill blank columns on
/// import, and to show on old entries saved with them blank. Staff can
/// still change them on the form.
library;

class RegisterDefaults {
  RegisterDefaults._();

  static const String lga = 'AMAC';
  static const String ward = 'Gwagwa';
  static const String facility = 'The Crown Hospital LTD';

  /// [value] trimmed, or [fallback] when it is blank.
  static String orDefault(String? value, String fallback) {
    final v = (value ?? '').trim();
    return v.isEmpty ? fallback : v;
  }
}
