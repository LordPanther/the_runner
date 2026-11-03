import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_runner/core/utils/friendly_error.dart';

void main() {
  group('friendlyErrorKey', () {
    final cases = <Object?, String>{
      null: 'error_generic',
      const SocketException('Failed host lookup'): 'error_network',
      TimeoutException('slow'): 'error_network',
      'Exception: Failed to load: [cloud_firestore/unavailable] The service is unavailable':
          'error_network',
      'Exception: [cloud_firestore/permission-denied] Missing permissions': 'error_permission',
      'OTP verification failed [invalid-verification-code]: bad code': 'error_wrong_code',
      'Phone sign-in failed [too-many-requests]: blocked': 'error_too_many',
      'Verification failed [invalid-phone-number]: format': 'enter_a_valid_phone_number',
      'Exception: Failed to place bid: Exception: You already placed a bid on this errand':
          'error_already_bid',
      'Exception: This errand is no longer open': 'error_errand_not_open',
      'Exception: Bid must be between the starting fee and the cap': 'error_bid_out_of_range',
      'Exception: Errand not found': 'error_not_found',
      'Exception: something odd happened': 'error_generic',
    };

    cases.forEach((input, expected) {
      test('$input -> $expected', () {
        expect(friendlyErrorKey(input), expected);
      });
    });
  });
}
