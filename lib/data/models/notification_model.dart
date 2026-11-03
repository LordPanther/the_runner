// lib/data/models/notification_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String userUid;
  final String type; // 'new_bid', 'bid_accepted', 'errand_funded', ...
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userUid,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // NOTE: notifications are actually CREATED via raw hand-written maps
  // (see FirebaseNotificationRepository._createNotification and similar)
  // which already correctly use snake_case ('user_uid', 'created_at') and
  // a native Timestamp - this model's fromMap() was reading the wrong
  // camelCase keys back, so every notification's parsed userUid came back
  // empty and its createdAt silently defaulted to "now" instead of the
  // real creation time (not a crash, since there was a fallback, but
  // every notification's relative time showed as "Just now" regardless
  // of when it actually happened).
  static NotificationModel fromMap(Map<String, dynamic> data, [String? documentId]) {
    return NotificationModel(
      id: documentId ?? data['id'] ?? '',
      userUid: data['user_uid'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      read: data['read'] ?? false,
      createdAt: _parseTimestamp(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_uid': userUid,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'read': read,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  NotificationModel cloneWith({
    String? id,
    String? userUid,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userUid: userUid ?? this.userUid,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, userUid: $userUid, type: $type, title: $title, body: $body, data: $data, read: $read, createdAt: $createdAt)';
  }

  @override
  List<Object?> get props => [
        id,
        userUid,
        type,
        title,
        body,
        data,
        read,
        createdAt,
      ];
}
