import 'package:flutter_test/flutter_test.dart';
import 'package:the_runner/core/utils/fees.dart';

void main() {
  group('Fees (5% requester + 5% runner)', () {
    test('R100 fee: requester pays R105, runner gets R95, platform keeps R10', () {
      expect(Fees.requesterTotal(100), 105);
      expect(Fees.runnerPayout(100), 95);
      expect(Fees.platformTake(100), 10);
    });

    test('purchase budget is added in full, never commissioned', () {
      expect(Fees.requesterTotal(60, purchaseBudget: 500), 563);
      expect(Fees.runnerPayout(60), 57);
    });

    test('rounds to whole cents', () {
      expect(Fees.requesterServiceFee(87.35), 4.37);
      expect(Fees.runnerPayout(87.35), 82.98);
    });

    test('formats like a South African price', () {
      expect(Fees.format(105), 'R105');
      expect(Fees.format(1234.5), 'R1 234.50');
      expect(Fees.format(1000000), 'R1 000 000');
    });
  });
}
