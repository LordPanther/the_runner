import 'package:flutter_test/flutter_test.dart';
import 'package:the_runner/core/utils/phone_number.dart';

void main() {
  group('normalizePhoneNumber (South Africa, +27)', () {
    const expected = '+27821234567';
    for (final typed in [
      '082 123 4567',
      '0821234567',
      '82 123 4567',
      '821234567',
      '+27 82 123 4567',
      '+27821234567',
      '27821234567',
      '0027821234567',
      '082-123-4567',
      '(082) 123 4567',
    ]) {
      test('"$typed"', () {
        expect(normalizePhoneNumber(typed, '+27'), expected);
      });
    }
  });

  group('validatePhoneNumber', () {
    test('accepts a normal SA mobile number', () {
      expect(validatePhoneNumber('082 123 4567', '+27'), isNull);
    });
    test('rejects an SA number that is too short', () {
      expect(validatePhoneNumber('082 123 45', '+27'), 'sa_phone_number_length');
    });
    test('rejects an SA number that is too long', () {
      expect(validatePhoneNumber('082 123 45678', '+27'), isNotNull);
    });
    test('rejects empty input', () {
      expect(validatePhoneNumber('  ', '+27'), 'enter_your_phone_number');
    });
    test('accepts a UK number', () {
      expect(validatePhoneNumber('07700 900123', '+44'), isNull);
      expect(normalizePhoneNumber('07700 900123', '+44'), '+447700900123');
    });
  });
}
