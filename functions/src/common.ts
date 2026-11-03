import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

if (admin.apps.length === 0) admin.initializeApp();

export const db = admin.firestore();
export const now = () => admin.firestore.Timestamp.now();
export const serverTime = () => admin.firestore.FieldValue.serverTimestamp();

/** Every status value, exactly as the app stores it (ErrandStatus.wire). */
export const Status = {
  draft: "draft",
  bidding: "bidding",
  accepted: "accepted",
  funded: "funded",
  inProgress: "in_progress",
  proofSubmitted: "proof_submitted",
  completed: "completed",
  disputed: "disputed",
  cancelled: "cancelled",
} as const;
export type StatusValue = typeof Status[keyof typeof Status];

/** Hours between proof and automatic payment release. */
export const AUTO_RELEASE_HOURS = 24;

export type Errand = FirebaseFirestore.DocumentData & {
  requester_uid: string;
  runner_uid?: string;
  status: StatusValue;
  title: string;
  type: string;
  starting_fee: number;
  fee_cap: number;
  agreed_fee?: number;
  instant_accept?: boolean;
  requester_fee_rate: number;
  runner_fee_rate: number;
  purchase_budget?: number;
  final_purchase_amount?: number;
  escrow?: {
    provider_ref?: string;
    held_amount?: number;
  };
};

export function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return auth.uid;
}

export function requireString(value: unknown, name: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `Missing ${name}.`);
  }
  return value.trim();
}

export const errandRef = (errandId: string) => db.collection("errands").doc(errandId);

/**
 * Moves an errand from one of [from] to [to] inside a transaction, and
 * writes an entry to errands/{id}/events: the money trail every
 * dispute will lean on.
 *
 * [check] runs inside the transaction with the current errand and may
 * throw (e.g. "only the requester can do this"). [extra] returns any
 * other fields to set alongside the status.
 *
 * Plain-English error messages are matched by the app's
 * friendly_error.dart, so keep wording in sync with it.
 */
export async function transition(
  errandId: string,
  actorUid: string,
  from: StatusValue[],
  to: StatusValue,
  options: {
    check?: (errand: Errand) => void;
    extra?: (errand: Errand) => Record<string, unknown>;
    tx?: (tx: FirebaseFirestore.Transaction, errand: Errand) => void;
    note?: string;
  } = {},
): Promise<Errand> {
  const ref = errandRef(errandId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Errand not found");
    const errand = snap.data() as Errand;
    if (!from.includes(errand.status)) {
      throw new HttpsError(
        "failed-precondition",
        "This errand has changed. Please refresh.",
      );
    }
    options.check?.(errand);
    const extra = options.extra?.(errand) ?? {};
    tx.update(ref, {status: to, updated_at: serverTime(), ...extra});
    tx.create(ref.collection("events").doc(), {
      from: errand.status,
      to,
      actor_uid: actorUid,
      note: options.note ?? null,
      at: serverTime(),
    });
    options.tx?.(tx, errand);
    return {...errand, ...extra, status: to} as Errand;
  });
}

export function onlyRequester(uid: string) {
  return (errand: Errand) => {
    if (errand.requester_uid !== uid) {
      throw new HttpsError("permission-denied", "Only the requester can do this.");
    }
  };
}

export function onlyRunner(uid: string) {
  return (errand: Errand) => {
    if (errand.runner_uid !== uid) {
      throw new HttpsError("permission-denied", "Only the runner can do this.");
    }
  };
}

/** "R1 234.50", matching the app's Fees.format. */
export function rand(amount: unknown): string {
  const value = Number(amount) || 0;
  const [whole, cents] = value.toFixed(2).split(".");
  const spaced = whole.replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  return cents === "00" ? `R${spaced}` : `R${spaced}.${cents}`;
}

/**
 * Creates one in-app notification (which sendPushOnNotificationCreated
 * then pushes). Keyed by [key] so a retried event can't notify twice.
 *
 * TODO(i18n): English only for now. Town Post's bilingual pattern
 * (users/{uid}/private/settings.language) slots in here once isiZulu
 * copy for errands is written.
 */
export async function notify(
  key: string,
  userUid: string | undefined,
  title: string,
  body: string,
  type: string,
  data: Record<string, string>,
): Promise<void> {
  if (!userUid) return;
  try {
    await db.collection("notifications").doc(key).create({
      user_uid: userUid,
      title,
      body,
      type,
      data,
      read: false,
      created_at: now(),
    });
  } catch (err: unknown) {
    if ((err as {code?: number}).code === 6) return; // ALREADY_EXISTS
    throw err;
  }
}
