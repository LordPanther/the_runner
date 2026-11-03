// lib/data/repositories/notification/firebase_notification_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:the_runner/data/models/notification_model.dart';
import 'package:the_runner/data/repositories/notification/notification_repository.dart';

// NOTE: fixed the same doc-casting bug found across the app in
// getNotifications() and streamNewNotifications() - both were casting the
// DocumentSnapshot itself instead of calling .data() on it, which throws
// "type '_JsonQueryDocumentSnapshot' is not a subtype of type
// 'Map<String, dynamic>'" the moment either actually ran. These two are
// what NotificationsScreen and the bottom-nav unread badge depend on.
class FirebaseNotificationRepository implements NotificationRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Notification tokens live in the PRIVATE account record
  // (users/{uid}/private/account), not the public profile, so other
  // users can't read them - see firestore.rules.
  DocumentReference<Map<String, dynamic>> _privateAccount(String uid) =>
      _firestore.collection('users').doc(uid).collection('private').doc('account');

  @override
  Future<void> saveFcmToken(String token) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) return;

      // merge: true creates the private record if it doesn't exist yet.
      await _privateAccount(currentUser.uid).set(
        {'fcmTokens': FieldValue.arrayUnion([token])},
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to save FCM token: $e');
    }
  }

  @override
  Future<void> removeFcmToken(String token) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) return;

      await _privateAccount(currentUser.uid).set(
        {'fcmTokens': FieldValue.arrayRemove([token])},
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to remove FCM token: $e');
    }
  }

  @override
  Future<List<NotificationModel>> getNotifications({
    int limit = 20,
    String? lastDocumentId,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) return [];

      Query queryRef = _firestore
          .collection('notifications')
          .where('user_uid', isEqualTo: currentUser.uid)
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (lastDocumentId != null) {
        final lastDoc = await _firestore
            .collection('notifications')
            .doc(lastDocumentId)
            .get();

        if (lastDoc.exists) {
          queryRef = queryRef.startAfter([lastDoc.data()!['created_at']]);
        }
      }

      final snapshot = await queryRef.get();

      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  @override
  Stream<NotificationModel> streamNewNotifications() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('user_uid', isEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .snapshots()
        .expand((snapshot) => snapshot.docs)
        .map((doc) => NotificationModel.fromMap(
              doc.data(),
              doc.id,
            ));
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) return;

      final snapshot = await _firestore
          .collection('notifications')
          .where('user_uid', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) return 0;

      final snapshot = await _firestore
          .collection('notifications')
          .where('user_uid', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .count()
          .get();

      return snapshot.count!;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  // Not part of NotificationRepository (hence no @override). Kept in
  // case anything still calls it directly.
  Future<void> sendNotification({
    required String userUid,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Save to Firestore
      await _firestore.collection('notifications').add({
        'user_uid': userUid,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'read': false,
        'created_at': Timestamp.now(),
      });

      // Also send push notification if FCM token exists
      // var userDoc = await _firestore.collection('users').doc(userUid).get();
      // if (userDoc.exists) {
      //   final fcmTokens = List<String>.from(
      //     userDoc.data()!['fcm_tokens'] ?? [],
      //   );

      //   for (final token in fcmTokens) {
      //     await _firebaseMessaging.send(
      //       token,
      //       notification: RemoteNotification(title: title, body: body),
      //       data: data ?? {},
      //     );
      //   }
      // }
    } catch (e) {
      throw Exception('Failed to send notification: $e');
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) return;

      final snapshot = await _firestore
          .collection('notifications')
          .where('user_uid', isEqualTo: currentUser.uid)
          .get();

      // Batches hold at most 500 writes.
      for (var i = 0; i < snapshot.docs.length; i += 450) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs.skip(i).take(450)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to clear notifications: $e');
    }
  }

  @override
  Future<void> initialize() async {
    // Nothing to set up here: push delivery is handled by the
    // sendPushOnNotificationCreated Cloud Function, and the token is
    // saved through saveFcmToken(). Previously this threw
    // UnimplementedError, so NotificationBloc's InitializeNotifications
    // always ended in NotificationError.
  }

  @override
  set onNotificationNavigation(Function(Map<String, dynamic> data) callback) {
    // TODO: implement onNotificationNavigation
  }
}