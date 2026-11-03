/**
 * The money maths, done on the server from the rates stored on each
 * errand. Mirrors lib/core/utils/fees.dart in the app; the app's
 * numbers are for display, these are the ones that actually move.
 *
 * 10% commission, split evenly: the requester pays fee + 5%, the
 * runner receives fee - 5%. Purchase money is never commissioned.
 */

const cents = (value: number) => Math.round(value * 100) / 100;

export interface Breakdown {
  /** What the requester pays into escrow. */
  requesterTotal: number;
  /** Fee the runner receives after their 5%. */
  runnerPayout: number;
  /** Purchase money paid back to the runner (shopping only). */
  purchaseReimbursement: number;
  /** Unspent budget returned to the requester (shopping only). */
  requesterRefund: number;
  /** The Runner's 10%. */
  platformTake: number;
}

export function breakdown(input: {
  agreedFee: number;
  requesterRate: number;
  runnerRate: number;
  purchaseBudget?: number;
  finalPurchaseAmount?: number;
}): Breakdown {
  const fee = input.agreedFee;
  const requesterFee = cents(fee * input.requesterRate);
  const runnerFee = cents(fee * input.runnerRate);
  const budget = input.purchaseBudget ?? 0;
  // Never reimburse more than the budget, whatever the receipt says.
  const spent = Math.min(input.finalPurchaseAmount ?? budget, budget);

  return {
    requesterTotal: cents(fee + requesterFee + budget),
    runnerPayout: cents(fee - runnerFee),
    purchaseReimbursement: cents(spent),
    requesterRefund: cents(budget - spent),
    platformTake: cents(requesterFee + runnerFee),
  };
}
