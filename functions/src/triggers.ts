import {onDocumentUpdated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {Errand, Status, db, errandRef, notify, rand} from "./common.js";
import {acceptBidInternal} from "./errands.js";

/**
 * Any bid created, edited or withdrawn:
 *   - keeps errands/{id}.bid_count equal to the number of pending bids
 *   - tells the requester about a new or edited bid
 *   - instant accept: a bid at exactly the starting fee is accepted
 *     straight away when the requester switched that on
 */
export const onBidWritten = onDocumentWritten(
  "errands/{errandId}/bids/{runnerUid}",
  async (event) => {
    const {errandId, runnerUid} = event.params;
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    const pending = await errandRef(errandId).collection("bids")
      .where("status", "==", "pending").count().get();
    await errandRef(errandId).update({bid_count: pending.data().count})
      .catch(() => undefined); // errand deleted with its account

    if (!after || after.status !== "pending") return;

    const errandSnap = await errandRef(errandId).get();
    const errand = errandSnap.data() as Errand | undefined;
    if (!errand || errand.status !== Status.bidding) return;

    const isNew = !before;
    const amountChanged = before && before.amount !== after.amount;
    if (!isNew && !amountChanged) return;

    if (isNew && errand.instant_accept && after.amount === errand.starting_fee) {
      try {
        await acceptBidInternal(errandId, runnerUid, "system");
        return; // onErrandUpdated tells both sides
      } catch (err) {
        console.warn(`Instant accept skipped for ${errandId}`, err);
      }
    }

    await notify(
      `evt_${event.id}_bid`,
      errand.requester_uid,
      isNew ? "New bid on your errand" : "A bid was updated",
      `${rand(after.amount)} for "${errand.title}"`,
      isNew ? "new_bid" : "bid_updated",
      {errand_id: errandId},
    );
  },
);

/**
 * Tells the right person whenever an errand changes status. One place
 * for every lifecycle message, so nothing is announced twice and no
 * client can send a fake one.
 */
export const onErrandUpdated = onDocumentUpdated("errands/{errandId}", async (event) => {
  const before = event.data?.before.data() as Errand | undefined;
  const after = event.data?.after.data() as Errand | undefined;
  if (!before || !after || before.status === after.status) return;

  const errandId = event.params.errandId;
  const title = `"${after.title}"`;
  const data = {errand_id: errandId};
  const key = (suffix: string) => `evt_${event.id}_${suffix}`;

  switch (after.status) {
  case Status.accepted: {
    await notify(key("runner"), after.runner_uid, "Your bid was accepted",
      `You're running ${title} for ${rand(after.agreed_fee)}. Wait for payment before you start.`,
      "bid_accepted", data);
    await notify(key("requester"), after.requester_uid, "Runner chosen",
      `Pay into escrow to get ${title} started.`, "bid_accepted", data);
    // Everyone else who bid.
    const declined = await errandRef(errandId).collection("bids")
      .where("status", "==", "rejected").get();
    await Promise.all(declined.docs.map((d) => notify(key(`declined_${d.id}`), d.id,
      "Errand taken", `${title} went to another runner.`, "bid_declined", data)));
    break;
  }
  case Status.funded:
    await notify(key("runner"), after.runner_uid, "Paid, you can start",
      `Payment for ${title} is held safely in escrow. Go ahead!`, "errand_funded", data);
    break;
  case Status.inProgress:
    await notify(key("requester"), after.requester_uid, "Your runner is on it",
      `${title} has started.`, "errand_started", data);
    break;
  case Status.proofSubmitted:
    await notify(key("requester"), after.requester_uid, "Errand done: check the proof",
      `Approve ${title}, or payment releases automatically in 24 hours.`,
      "proof_submitted", data);
    break;
  case Status.completed:
    await notify(key("runner"), after.runner_uid, "Payment released",
      `You've been paid for ${title}.`, "payment_released", data);
    await notify(key("requester"), after.requester_uid, "Errand complete",
      `Thanks for using The Runner for ${title}.`, "errand_completed", data);
    break;
  case Status.disputed:
    await notify(key("runner"), after.runner_uid, "Dispute raised",
      `The requester raised a dispute on ${title}. Payment is on hold while we look into it.`,
      "errand_disputed", data);
    break;
  case Status.cancelled: {
    const by = after.cancelled_by as string | undefined;
    // The schedule sends its own "no bids" message.
    if (by === "system") break;
    const other = by === after.requester_uid ? after.runner_uid : after.requester_uid;
    await notify(key("other"), other, "Errand cancelled",
      before.status === Status.funded ?
        `${title} was cancelled. Any payment is refunded.` :
        `${title} was cancelled.`,
      "errand_cancelled", data);
    if (before.status === Status.bidding) {
      const bids = await errandRef(errandId).collection("bids")
        .where("status", "==", "pending").get();
      const batch = db.batch();
      bids.docs.forEach((d) => batch.update(d.ref, {status: "rejected"}));
      await batch.commit();
    }
    break;
  }
  default:
    break;
  }
});
