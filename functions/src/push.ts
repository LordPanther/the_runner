import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import "./common.js"; // initialises the Admin SDK

/**
 * Triggers whenever a new document is created in the `notifications`
 * collection and sends the actual FCM push to every device the recipient
 * has registered. Notifications are created ONLY by the server (the
 * triggers in triggers.ts and scheduled.ts) - the rules block every
 * client, so nobody can send a fake "The Runner" notification.
 */
export const sendPushOnNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notification = snapshot.data();
    const userUid: string | undefined = notification.user_uid;
    const title: string | undefined = notification.title;
    const body: string | undefined = notification.body;
    const data: Record<string, unknown> = notification.data || {};

    if (!userUid || !title || !body) {
      console.warn(
        `Notification ${event.params.notificationId} is missing ` +
        "user_uid, title, or body - skipping push"
      );
      return;
    }

    // Tokens live in the PRIVATE account record (users/{uid}/private/
    // account), not on the public profile, so other users can't read
    // them. Older accounts not yet moved over still have them on the
    // public profile - read both until every account has moved.
    const userRef = admin.firestore().collection("users").doc(userUid);
    const privateRef = userRef.collection("private").doc("account");
    const [privateDoc, userDoc] = await Promise.all([privateRef.get(), userRef.get()]);
    if (!userDoc.exists && !privateDoc.exists) {
      console.warn(`User ${userUid} not found - skipping push`);
      return;
    }

    // Field name stays camelCase (fcmTokens), matching UserModel.
    const tokens: string[] = Array.from(new Set<string>([
      ...(privateDoc.data()?.fcmTokens || []),
      ...(userDoc.data()?.fcmTokens || []),
    ]));
    if (tokens.length === 0) {
      // Not an error - the user just hasn't granted notification
      // permission yet, or hasn't opened the app since this shipped.
      return;
    }

    // FCM's data payload requires every value to be a string, unlike
    // the Firestore document it came from which can hold any type.
    const stringData: Record<string, string> = {};
    for (const key of Object.keys(data)) {
      stringData[key] = String(data[key]);
    }

    const response = await admin.messaging().sendEachForMulticast({
      notification: {title, body},
      data: stringData,
      tokens,
    });

    // Clean up tokens FCM reports as permanently invalid (app
    // uninstalled, data cleared, token naturally rotated out) rather
    // than letting them silently accumulate in fcmTokens forever and
    // wasting a send attempt on every future notification.
    const invalidTokens: string[] = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const errorCode = res.error?.code;
        if (
          errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/registration-token-not-registered"
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      const remove = {fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)};
      if (privateDoc.exists) await privateRef.update(remove);
      if (userDoc.data()?.fcmTokens) await userRef.update(remove);
    }
  }
);
