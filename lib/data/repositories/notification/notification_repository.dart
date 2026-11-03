// lib/data/repositories/notification/notification_repository.dart

import 'package:the_runner/data/models/notification_model.dart';

abstract class NotificationRepository {
  // Initialization
  Future<void> initialize();

  // Token management
  Future<void> saveFcmToken(String token);
  Future<void> removeFcmToken(String token);

  // Getting notifications
  Future<List<NotificationModel>> getNotifications({
    int limit,
    String? lastDocumentId,
  });
  Stream<NotificationModel> streamNewNotifications();

  // Notification management
  Future<int> getUnreadCount();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String notificationId);
  Future<void> clearAllNotifications();

  // NOTE: no "send" methods here. Every user-to-user notification
  // (new bid, bid accepted, errand funded, proof submitted, released,
  // disputed) is created by Cloud Functions reacting to the change
  // itself, so a modified app can't send fake ones.

  // Navigation callback
  set onNotificationNavigation(Function(Map<String, dynamic> data) callback);
}
