// lib/core/utils/fees.dart

/// The Runner's 10% commission, split evenly so neither side feels like
/// they carry it alone: the requester pays the agreed fee + 5%, the
/// runner receives the agreed fee - 5%, the platform keeps the gap.
///
/// The purchase budget on shopping errands is NEVER part of this maths.
/// Taking a cut of someone's groceries would kill trust fast.
///
/// These are display numbers. The amounts that actually move are worked
/// out again on the server (functions/src/fees.ts) from the stored
/// rates, so a modified app can't change what anyone pays.
class Fees {
  static const double defaultRequesterRate = 0.05;
  static const double defaultRunnerRate = 0.05;

  /// Rounds to whole cents. Money is never shown or stored with more
  /// precision than a till receipt.
  static double roundCents(double value) => (value * 100).round() / 100;

  /// What the requester's 5% service fee comes to on [fee].
  static double requesterServiceFee(
    double fee, {
    double rate = defaultRequesterRate,
  }) =>
      roundCents(fee * rate);

  /// What the runner's 5% platform fee comes to on [fee].
  static double runnerPlatformFee(
    double fee, {
    double rate = defaultRunnerRate,
  }) =>
      roundCents(fee * rate);

  /// Total the requester pays into escrow: fee + service fee, plus the
  /// purchase budget on shopping errands.
  static double requesterTotal(
    double fee, {
    double purchaseBudget = 0,
    double rate = defaultRequesterRate,
  }) =>
      roundCents(fee + requesterServiceFee(fee, rate: rate) + purchaseBudget);

  /// What lands in the runner's bank account for [fee] (purchase money
  /// is reimbursed separately and in full).
  static double runnerPayout(
    double fee, {
    double rate = defaultRunnerRate,
  }) =>
      roundCents(fee - runnerPlatformFee(fee, rate: rate));

  /// The platform's share: both 5% halves together.
  static double platformTake(
    double fee, {
    double requesterRate = defaultRequesterRate,
    double runnerRate = defaultRunnerRate,
  }) =>
      roundCents(
        requesterServiceFee(fee, rate: requesterRate) +
            runnerPlatformFee(fee, rate: runnerRate),
      );

  /// "R 1 234.50" style, matching how South African prices are written.
  static String format(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );
    final cents = parts[1] == '00' ? '' : '.${parts[1]}';
    return 'R$whole$cents';
  }

  Fees._();
}
