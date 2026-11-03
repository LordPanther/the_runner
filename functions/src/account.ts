import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {Status, db, notify, requireUid} from "./common.js";
import {escrow} from "./escrow.js";
import {releaseFunds} from "./errands.js";

/**
 * Deletes the caller's account and everything tied to it. Runs on the
 * server because it touches other people's errands, which the rules
 * (rightly) never let a phone do.
 *
 * Errands with money in escrow are cancelled and refunded first, so a
 * deleted account can never strand someone else's payment.
 */
export const deleteAccount = onCall(
  {timeoutSeconds: 300, memory: "512MiB"},
  async (request) => {
    const uid = requireUid(request.auth);
    if (request.data?.confirm !== "DELETE") {
      throw new HttpsError("invalid-argument", "Deletion was not confirmed.");
    }

    const bucket = admin.storage().bucket();
    const writer = db.bulkWriter();
    const active = [Status.bidding, Status.accepted, Status.funded, Status.inProgress];

    // 1. Errands they POSTED
    const posted = await db.collection("errands").where("requester_uid", "==", uid).get();
    for (const doc of posted.docs) {
      const status = doc.get("status");
      if (status === Status.bidding || status === Status.draft) {
        await db.recursiveDelete(doc.ref); // errand + bids + private details
        continue;
      }
      if ((active as string[]).includes(status)) {
        await cancelAndRefund(doc, uid, "The requester has left The Runner");
      } else if (status === Status.proofSubmitted) {
        // The runner already did the work: pay them now rather than
        // leave it to the 24-hour clock. Disputed errands are left for
        // an admin to settle.
        await releaseFunds(doc.id, "system", [Status.proofSubmitted]);
      }
      writer.delete(doc.ref.collection("private").doc("details"));
      writer.update(doc.ref, {requester_deleted: true});
    }

    // 2. Errands they were RUNNING
    const running = await db.collection("errands").where("runner_uid", "==", uid).get();
    for (const doc of running.docs) {
      if ((active as string[]).includes(doc.get("status"))) {
        await cancelAndRefund(doc, uid, "The runner has left The Runner");
      }
      writer.update(doc.ref, {runner_deleted: true});
    }

    // 3. Their bids (orderBy matches the My Bids collection-group index)
    const bids = await db.collectionGroup("bids")
      .where("runner_uid", "==", uid).orderBy("created_at", "desc").get();
    bids.docs.forEach((d) => writer.delete(d.ref));

    // 4. Their notifications
    const notifications = await db.collection("notifications").where("user_uid", "==", uid).get();
    notifications.docs.forEach((d) => writer.delete(d.ref));

    await writer.close();

    // 5. Profile (with all subcollections) and files
    await db.recursiveDelete(db.collection("users").doc(uid));
    await bucket.deleteFiles({prefix: `users/${uid}/`, force: true});

    // 6. The sign-in itself, last: if anything above failed, the user
    // can still sign in and try again.
    try {
      await admin.auth().deleteUser(uid);
    } catch (err: unknown) {
      if ((err as {code?: string}).code !== "auth/user-not-found") throw err;
    }

    console.log(`Deleted account ${uid}`);
    return {deleted: true};
  },
);

async function cancelAndRefund(
  doc: FirebaseFirestore.QueryDocumentSnapshot,
  uid: string,
  reason: string,
) {
  const wasFunded = [Status.funded, Status.inProgress].includes(doc.get("status"));
  await doc.ref.update({
    status: Status.cancelled,
    cancelled_by: uid,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  const ref = doc.get("escrow.provider_ref");
  if (wasFunded && ref) {
    try {
      await escrow().refund(ref);
    } catch (err) {
      console.error(`REFUND FAILED for errand ${doc.id} - retry manually`, err);
      await doc.ref.update({"escrow.refund_failed": true});
    }
  }
  const other = doc.get("requester_uid") === uid ? doc.get("runner_uid") : doc.get("requester_uid");
  await notify(`deleted_${doc.id}`, other, "Errand cancelled",
    `${reason}, so "${doc.get("title")}" is cancelled.${wasFunded ? " Any payment is refunded." : ""}`,
    "errand_cancelled", {errand_id: doc.id});
}

/**
 * Returns another user's phone number, but only when the caller is
 * allowed to see it: your own number, or the other party on an errand
 * you share that's past the bidding stage. Phone numbers live in each
 * user's private account record, so this is the ONE way the app gets
 * someone else's number.
 */
export const getContactPhone = onCall(async (request) => {
  const callerUid = requireUid(request.auth);
  const targetUid: unknown = request.data?.uid;
  const errandId: unknown = request.data?.errandId;
  if (typeof targetUid !== "string" || targetUid.length === 0) {
    throw new HttpsError("invalid-argument", "Missing user.");
  }

  let allowed = targetUid === callerUid;
  if (!allowed && typeof errandId === "string" && errandId.length > 0) {
    const errand = await db.collection("errands").doc(errandId).get();
    const parties = [errand.get("requester_uid"), errand.get("runner_uid")];
    allowed = errand.exists &&
      [Status.funded, Status.inProgress, Status.proofSubmitted, Status.disputed]
        .includes(errand.get("status")) &&
      parties.includes(callerUid) && parties.includes(targetUid);
  }
  if (!allowed) {
    throw new HttpsError("permission-denied", "You can't see this phone number.");
  }

  const userRef = db.collection("users").doc(targetUid);
  const privateDoc = await userRef.collection("private").doc("account").get();
  return {phoneNumber: (privateDoc.get("phoneNumber") as string | undefined) ?? null};
});
