// lib/core/utils/phone_number.dart

/// Turns whatever a person types into a full international number
/// (E.164, e.g. +27821234567) for the country they picked.
///
/// South Africans almost always type their number the local way, with
/// the trunk 0 in front ("082 123 4567"). Glued straight onto +27 that
/// became +270821234567, which Firebase rejects, so most first sign-ins
/// failed. This accepts every common way of typing it:
///
///   082 123 4567     -> +27821234567
///   0821234567       -> +27821234567
///   82 123 4567      -> +27821234567
///   +27 82 123 4567  -> +27821234567
///   27821234567      -> +27821234567
///   0027821234567    -> +27821234567
String normalizePhoneNumber(String input, String dialCode) {
  final dial = dialCode.replaceAll(RegExp(r'[^0-9]'), '');
  final typed = input.trim();
  var digits = typed.replaceAll(RegExp(r'[^0-9]'), '');

  // Typed in full international form already: +27..., or 0027...
  if (typed.startsWith('+')) return '+$digits';
  if (digits.startsWith('00')) return '+${digits.substring(2)}';

  // Country code typed without the plus (27821234567), as long as
  // enough digits remain to be a real national number.
  if (digits.startsWith(dial) && digits.length - dial.length >= 8) {
    digits = digits.substring(dial.length);
  }

  // The local trunk prefix: 0 in front of the national number.
  digits = digits.replaceFirst(RegExp(r'^0+'), '');

  return '+$dial$digits';
}

/// Null when the typed number looks valid for the chosen country,
/// otherwise the TRANSLATION KEY of the message to show under the field
/// (see assets/locale/*.json) - the screen passes it through Translate.
String? validatePhoneNumber(String input, String dialCode) {
  final normalized = normalizePhoneNumber(input, dialCode);
  final dial = dialCode.replaceAll(RegExp(r'[^0-9]'), '');
  final allDigits = normalized.substring(1);

  if (input.trim().isEmpty) return 'enter_your_phone_number';

  // South African mobile numbers are always 9 digits after +27.
  if (dial == '27' && allDigits.startsWith('27')) {
    final national = allDigits.substring(2);
    if (national.length != 9) {
      return 'sa_phone_number_length';
    }
    return null;
  }

  // Other countries: E.164 allows 8 to 15 digits in total.
  if (allDigits.length < 8 || allDigits.length > 15) {
    return 'enter_a_valid_phone_number';
  }
  return null;
}
