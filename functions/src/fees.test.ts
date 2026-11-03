import {test} from "node:test";
import assert from "node:assert/strict";
import {breakdown} from "./fees.js";

const rates = {requesterRate: 0.05, runnerRate: 0.05};

test("R100 fee: requester pays R105, runner gets R95, platform keeps R10", () => {
  const money = breakdown({agreedFee: 100, ...rates});
  assert.equal(money.requesterTotal, 105);
  assert.equal(money.runnerPayout, 95);
  assert.equal(money.platformTake, 10);
  assert.equal(money.purchaseReimbursement, 0);
  assert.equal(money.requesterRefund, 0);
});

test("shopping: commission never touches the purchase budget", () => {
  const money = breakdown({agreedFee: 60, ...rates, purchaseBudget: 500, finalPurchaseAmount: 432.5});
  assert.equal(money.requesterTotal, 563);
  assert.equal(money.runnerPayout, 57);
  assert.equal(money.purchaseReimbursement, 432.5);
  assert.equal(money.requesterRefund, 67.5);
  assert.equal(money.platformTake, 6);
});

test("a receipt over budget is capped at the budget", () => {
  const money = breakdown({agreedFee: 60, ...rates, purchaseBudget: 200, finalPurchaseAmount: 250});
  assert.equal(money.purchaseReimbursement, 200);
  assert.equal(money.requesterRefund, 0);
});

test("every rand is accounted for", () => {
  const money = breakdown({agreedFee: 87.35, ...rates, purchaseBudget: 300, finalPurchaseAmount: 199.99});
  const paidOut = money.runnerPayout + money.purchaseReimbursement +
    money.requesterRefund + money.platformTake;
  assert.equal(Math.round(paidOut * 100), Math.round(money.requesterTotal * 100));
});
