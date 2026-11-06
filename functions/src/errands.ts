import * as admin from "firebase-admin";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {
  AUTO_RELEASE_HOURS,
  Errand,
  Status,
  StatusValue,
  db,
  errandRef,
  now,
  onlyRequester,
  onlyRunner,
  requireString,
  requireUid,
  serverTime,
  transition,
} from "./common.js";
import {escrow} from "./escrow.js";
import {breakdown} from "./fees.js";
import {approximate, geohashEncode} from "./geo.js";

/**
 * Every errand status change from `accepted` onward lives here. Each
 * one either moves money or decides who gets it, so the app is never
 * allowed to make them itself (see firestore.rules).
 */

const moneyFor = (errand: Errand) => breakdown({
  agreedFee: errand.agreed_fee ?? 0,
  requesterRate: errand.requester_fee_rate,
  runnerRate: errand.runner_fee_rate,
  purchaseBudget: errand.purchase_budget,
  finalPurchaseAmount: errand.final_purchase_amount,
});

// ── Accepting a bid ────────────────────────────────────────────

/**
 * Locks the price and the runner, all in one transaction: the errand
 * moves to `accepted` with runner_uid and agreed_fee taken from the bid
 * itself (never from anything the caller sent), the bid is marked
 * accepted and every other pending bid is declined.
 *
 * Shared by the acceptBid callable and the instant-accept trigger
 * (actorUid "system").
 */
export async function acceptBidInternal(
  errandId: string,
  runnerUid: string,
  actorUid: string,
): Promise<void> {
  const ref = errandRef(errandId);
  const bids = ref.collection("bids");

  await db.runTransaction(async (tx) => {
    const [errandSnap, bidSnap, pending] = await Promise.all([
      tx.get(ref),
      tx.get(bids.doc(runnerUid)),
      tx.get(bids.where("status", "==", "pending")),
    ]);
    if (!errandSnap.exists) throw new HttpsError("not-found", "Errand not found");
    const errand = errandSnap.data() as Errand;

    if (actorUid !== "system") onlyRequester(actorUid)(errand);
    if (errand.status !== Status.bidding || !bidSnap.exists ||
        bidSnap.get("status") !== "pending") {
      throw new HttpsError("failed-precondition", "This errand has changed. Please refresh.");
    }
    if (runnerUid === errand.requester_uid) {
      throw new HttpsError("invalid-argument", "You can't run your own errand.");
    }

    tx.update(ref, {
      status: Status.accepted,
      runner_uid: runnerUid,
      agreed_fee: bidSnap.get("amount"),
      updated_at: serverTime(),
    });
    tx.update(bidSnap.ref, {status: "accepted"});
    for (const doc of pending.docs) {
      if (doc.id !== runnerUid) tx.update(doc.ref, {status: "rejected"});
    }
    tx.create(ref.collection("events").doc(), {
      from: Status.bidding,
      to: Status.accepted,
      actor_uid: actorUid,
      note: `bid ${bidSnap.get("amount")} from ${runnerUid}`,
      at: serverTime(),
    });
  });
}

export const acceptBid = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const errandId = requireString(request.data?.errandId, "errand");
  const runnerUid = requireString(request.data?.runnerUid, "runner");
  await acceptBidInternal(errandId, runnerUid, uid);
  return {ok: true};
});

// ── Paying into escrow ─────────────────────────────────────────

export const startPayment = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const errandId = requireString(request.data?.errandId, "errand");

  const snap = await errandRef(errandId).get();
  if (!snap.exists) throw new HttpsError("not-found", "Errand not found");
  const errand = snap.data() as Errand;
  onlyRequester(uid)(errand);
  if (errand.status !== Status.accepted || !errand.runner_uid || !errand.agreed_fee) {
    throw new HttpsError("failed-precondition", "This errand has changed. Please refresh.");
  }

  const money = moneyFor(errand);
  const provider = escrow();
  const payment = await provider.createPayment({
    errandId,
    title: errand.title,
    requesterUid: errand.requester_uid,
    runnerUid: errand.runner_uid,
    money,
  });

  await errandRef(errandId).update({
    "escrow.provider": provider.name,
    "escrow.provider_ref": payment.providerRef,
    "escrow.held_amount": money.requesterTotal,
    "updated_at": serverTime(),
  });

  if (payment.fundedImmediately) {
    await markFunded(errandId, "system");
  }
  return {paymentUrl: payment.paymentUrl};
});

async function markFunded(errandId: string, actorUid: string) {
  await transition(errandId, actorUid, [Status.accepted], Status.funded, {
    extra: () => ({"escrow.funded_at": now()}),
  });
}

/**
 * TradeSafe calls this when the requester's payment clears.
 *
 * TODO(tradesafe): verify the request signature before trusting it,
 * and map TradeSafe's payload to our errand. Until then this endpoint
 * rejects everything, so nobody can fake a payment.
 */
export const tradesafeWebhook = onRequest(async (req, res) => {
  console.warn("tradesafeWebhook called before TradeSafe is connected", req.body);
  res.status(501).send("Not configured");
});

// ── Doing the errand ───────────────────────────────────────────

export const startErrand = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const errandId = requireString(request.data?.errandId, "errand");
  await transition(errandId, uid, [Status.funded], Status.inProgress, {
    check: onlyRunner(uid),
  });
  return {ok: true};
});

export const submitProof = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const errandId = requireString(request.data?.errandId, "errand");
  const photoUrls: unknown = request.data?.photoUrls;
  const receiptUrl: unknown = request.data?.receiptUrl;
  const total: unknown = request.data?.finalPurchaseAmount;
  const note = typeof request.data?.note === "string" ? request.data.note.slice(0, 500) : "";

  if (!Array.isArray(photoUrls) || photoUrls.length === 0 ||
      !photoUrls.every((u) => typeof u === "string")) {
    throw new HttpsError("invalid-argument", "Add at least one photo.");
  }

  const releaseAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + AUTO_RELEASE_HOURS * 60 * 60 * 1000,
  );

  await transition(errandId, uid, [Status.inProgress], Status.proofSubmitted, {
    check: (errand) => {
      onlyRunner(uid)(errand);
      if (errand.type === "shopping") {
        if (typeof receiptUrl !== "string" || typeof total !== "number") {
          throw new HttpsError("invalid-argument", "Add the till slip and its total.");
        }
        if (total > (errand.purchase_budget ?? 0)) {
          throw new HttpsError("invalid-argument", "That's more than the purchase budget.");
        }
      }
    },
    extra: (errand) => ({
      auto_release_at: releaseAt,
      ...(errand.type === "shopping" ? {final_purchase_amount: total} : {}),
    }),
    tx: (tx) => {
      tx.create(errandRef(errandId).collection("proofs").doc(), {
        runner_uid: uid,
        photo_urls: photoUrls,
        receipt_url: typeof receiptUrl === "string" ? receiptUrl : null,
        final_purchase_amount: typeof total === "number" ? total : null,
        note,
        created_at: serverTime(),
      });
    },
  });
  return {ok: true};
});

// ── Finishing ──────────────────────────────────────────────────

/**
 * Pays out: runner fee - 5% plus purchase money to the runner, unspent
 * budget back to the requester, 10% to The Runner. Called on approval,
 * by the auto-release schedule, and when a dispute resolves in the
 * runner's favour.
 */
export async function releaseFunds(
  errandId: string,
  actorUid: string,
  from: StatusValue[],
): Promise<void> {
  const errand = await transition(errandId, actorUid, from, Status.completed, {
    check: (e) => {
      if (actorUid !== "system") onlyRequester(actorUid)(e);
    },
    extra: () => ({"escrow.released_at": now(), "auto_release_at": null}),
  });
  const ref = errand.escrow?.provider_ref;
  if (ref) {
    // After the status change: if the provider call fails, the errand
    // shows completed and the failure is logged for a manual retry,
    // rather than money moving twice on a retry.
    try {
      await escrow().release(ref, moneyFor(errand));
    } catch (err) {
      console.error(`RELEASE FAILED for errand ${errandId} - retry manually`, err);
      await errandRef(errandId).update({"escrow.release_failed": true});
    }
  }
}

export const approveCompletion = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const errandId = requireString(request.data?.errandId, "errand");
  await releaseFunds(errandId, uid, [Status.proofSubmitted]);
  return {ok: true};
});

export const raiseDispute = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const errandId = requireString(request.data?.errandId, "errand");
  const reason = requireString(request.data?.reason, "reason").slice(0, 1000);

  await transition(errandId, uid, [Status.proofSubmitted], Status.disputed, {
    check: onlyRequester(uid),
    // The clock stops: nothing is released while a dispute is open.
    extra: () => ({auto_release_at: null}),
    note: reason,
    tx: (tx, errand) => {
      tx.create(db.collection("disputes").doc(errandId), {
        errand_id: errandId,
        raised_by: uid,
        requester_uid: errand.requester_uid,
        runner_uid: errand.runner_uid ?? null,
        reason,
        status: "open",
        resolution: null,
        created_at: serverTime(),
      });
    },
  });
  return {ok: true};
});

/**
 * Either side calls this off. Requesters can cancel any time before the
 * runner starts; runners can back out once accepted, before starting.
 * If money was held, it all goes back to the requester.
 */
export const cancelErrand = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const errandId = requireString(request.data?.errandId, "errand");
  const reason = typeof request.data?.reason === "string" ? request.data.reason.slice(0, 500) : "";

  let wasFunded = false;
  const errand = await transition(
    errandId,
    uid,
    [Status.bidding, Status.accepted, Status.funded],
    Status.cancelled,
    {
      check: (e) => {
        const isRequester = e.requester_uid === uid;
        const isRunner = e.runner_uid === uid && e.status !== Status.bidding;
        if (!isRequester && !isRunner) {
          throw new HttpsError("permission-denied", "Only the requester can do this.");
        }
        wasFunded = e.status === Status.funded;
      },
      extra: (e) => ({
        cancelled_by: uid,
        ...(e.status === Status.funded ? {"escrow.refunded_at": now()} : {}),
      }),
      note: reason,
    },
  );

  // Only money that actually arrived is refunded. A payment that was
  // started but never completed has nothing to give back.
  const ref = errand.escrow?.provider_ref;
  if (wasFunded && ref) {
    try {
      await escrow().refund(ref);
    } catch (err) {
      console.error(`REFUND FAILED for errand ${errandId} - retry manually`, err);
      await errandRef(errandId).update({"escrow.refund_failed": true});
    }
  }
  return {ok: true};
});

// ── Editing and relisting ──────────────────────────────────────

const num = (value: unknown, name: string): number => {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `Missing ${name}.`);
  }
  return value;
};

const text = (value: unknown, max: number): string =>
  typeof value === "string" ? value.trim().slice(0, max) : "";

/**
 * The requester edits an errand nobody has bid on and puts it back up
 * for bids: one that expired with no bids (cancelled by the schedule),
 * or one still open with no bids yet. Same errand, same id: no
 * duplicates in anyone's lists.
 *
 * Done here rather than in the app because errand updates from clients
 * are blocked outright (firestore.rules), and the location fields must
 * be recomputed exactly as on create.
 */
export const relistErrand = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const d = request.data ?? {};
  const errandId = requireString(d.errandId, "errand");

  const title = text(d.title, 60);
  if (!title) throw new HttpsError("invalid-argument", "Missing title.");
  const startingFee = num(d.startingFee, "starting fee");
  const feeCap = num(d.feeCap, "cap");
  if (startingFee <= 0) throw new HttpsError("invalid-argument", "Missing starting fee.");
  if (feeCap < startingFee) {
    throw new HttpsError("invalid-argument", "The cap must be at least the starting fee.");
  }
  const biddingClosesAt = num(d.biddingClosesAtMs, "bidding window");
  if (biddingClosesAt <= Date.now()) {
    throw new HttpsError("invalid-argument", "Pick a bidding window.");
  }
  const deadline = typeof d.deadlineMs === "number" ? d.deadlineMs : null;

  const details = d.details ?? {};
  const pickupLat = num(details.pickupLat, "pickup");
  const pickupLng = num(details.pickupLng, "pickup");
  const pickupAddress = text(details.pickupAddress, 300);
  if (!pickupAddress) throw new HttpsError("invalid-argument", "Missing pickup.");

  const ref = errandRef(errandId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Errand not found");
    const errand = snap.data() as Errand;
    onlyRequester(uid)(errand);

    const expiredUnbid = errand.status === Status.cancelled && errand.cancelled_by === "system";
    const openUnbid = errand.status === Status.bidding && (errand.bid_count ?? 0) === 0;
    if (!expiredUnbid && !openUnbid) {
      throw new HttpsError("failed-precondition", "This errand has changed. Please refresh.");
    }

    const type = errand.type;
    const budget = type === "shopping" ? num(d.purchaseBudget, "purchase budget") : null;
    if (budget !== null && budget <= 0) {
      throw new HttpsError("invalid-argument", "Missing purchase budget.");
    }

    const lat = approximate(pickupLat);
    const lng = approximate(pickupLng);
    tx.update(ref, {
      title,
      description: text(d.description, 500),
      area_label: text(d.areaLabel, 80),
      lat,
      lng,
      geohash: geohashEncode(lat, lng),
      deadline: deadline ? admin.firestore.Timestamp.fromMillis(deadline) : null,
      bidding_closes_at: admin.firestore.Timestamp.fromMillis(biddingClosesAt),
      starting_fee: startingFee,
      fee_cap: feeCap,
      instant_accept: d.instantAccept === true,
      ...(budget !== null ? {purchase_budget: budget} : {}),
      status: Status.bidding,
      cancelled_by: admin.firestore.FieldValue.delete(),
      relisted_count: admin.firestore.FieldValue.increment(1),
      updated_at: serverTime(),
    });
    tx.set(ref.collection("private").doc("details"), {
      pickup_address: pickupAddress,
      pickup_lat: pickupLat,
      pickup_lng: pickupLng,
      dropoff_address: text(details.dropoffAddress, 300),
      dropoff_lat: typeof details.dropoffLat === "number" ? details.dropoffLat : null,
      dropoff_lng: typeof details.dropoffLng === "number" ? details.dropoffLng : null,
      shopping_list: Array.isArray(details.shoppingList) ?
        details.shoppingList.filter((i: unknown) => typeof i === "string").slice(0, 100) :
        [],
      instructions: text(details.instructions, 500),
    });
    tx.create(ref.collection("events").doc(), {
      from: errand.status,
      to: Status.bidding,
      actor_uid: uid,
      note: expiredUnbid ? "relisted after expiring with no bids" : "edited before any bids",
      at: serverTime(),
    });
  });
  return {ok: true};
});
