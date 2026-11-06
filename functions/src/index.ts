/**
 * The Runner Cloud Functions.
 *
 *   errands.ts    every money-moving status change (callables + webhook)
 *   triggers.ts   bid bookkeeping, instant accept, lifecycle notifications
 *   scheduled.ts  auto-release after 24h, reminders, expiring empty errands
 *   escrow.ts     the escrow provider (fake for testing, TradeSafe for real)
 *   fees.ts       the 5% + 5% commission maths
 *   account.ts    account deletion, contact phone numbers
 *   push.ts       FCM push for every notification document
 */
export {
  acceptBid,
  approveCompletion,
  cancelErrand,
  raiseDispute,
  relistErrand,
  startErrand,
  startPayment,
  submitProof,
  tradesafeWebhook,
} from "./errands.js";
export {onBidWritten, onErrandUpdated} from "./triggers.js";
export {errandHousekeeping} from "./scheduled.js";
export {deleteAccount, getContactPhone} from "./account.js";
export {sendPushOnNotificationCreated} from "./push.js";
