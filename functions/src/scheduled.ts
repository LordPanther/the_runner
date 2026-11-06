import {onSchedule} from "firebase-functions/v2/scheduler";
import {Status, db, notify, now} from "./common.js";
import {releaseFunds} from "./errands.js";
import * as admin from "firebase-admin";

/**
 * Every 15 minutes:
 *   1. Releases payment on errands whose 24-hour approval window has
 *      run out (proof submitted, requester said nothing).
 *   2. Reminds requesters when about 4 hours are left.
 *   3. Cancels errands whose bidding closed with no bids at all.
 *
 * Needs composite indexes errands: status + auto_release_at and
 * errands: status + bidding_closes_at (firestore.indexes.json).
 */
export const errandHousekeeping = onSchedule(
  {schedule: "every 15 minutes", timeZone: "Africa/Johannesburg"},
  async () => {
    const errands = db.collection("errands");
    const nowTs = now();

    // 1. Auto-release
    const due = await errands
      .where("status", "==", Status.proofSubmitted)
      .where("auto_release_at", "<=", nowTs)
      .limit(100).get();
    for (const doc of due.docs) {
      try {
        await releaseFunds(doc.id, "system", [Status.proofSubmitted]);
      } catch (err) {
        console.error(`Auto-release failed for ${doc.id}`, err);
      }
    }

    // 2. Reminder, once, with ~4 hours to go
    const soon = admin.firestore.Timestamp.fromMillis(Date.now() + 4 * 60 * 60 * 1000);
    const nearlyDue = await errands
      .where("status", "==", Status.proofSubmitted)
      .where("auto_release_at", "<=", soon)
      .limit(100).get();
    for (const doc of nearlyDue.docs) {
      await notify(
        `reminder_${doc.id}`,
        doc.get("requester_uid"),
        "Payment releases soon",
        `Check the proof for "${doc.get("title")}". Payment releases automatically in a few hours.`,
        "auto_release_reminder",
        {errand_id: doc.id},
      );
    }

    // 3. Bidding closed with nobody interested
    const closed = await errands
      .where("status", "==", Status.bidding)
      .where("bidding_closes_at", "<=", nowTs)
      .limit(100).get();
    for (const doc of closed.docs) {
      if ((doc.get("bid_count") ?? 0) > 0) continue; // requester can still pick
      await doc.ref.update({status: Status.cancelled, cancelled_by: "system", updated_at: nowTs});
      await notify(
        // Per listing, so a relisted errand that expires again is announced again.
        `expired_${doc.id}_${doc.get("relisted_count") ?? 0}`,
        doc.get("requester_uid"),
        "No bids this time",
        `Nobody bid on "${doc.get("title")}" before bidding closed. ` +
          "Open it to edit and relist, e.g. with a higher cap.",
        "errand_cancelled",
        {errand_id: doc.id},
      );
    }
  },
);
