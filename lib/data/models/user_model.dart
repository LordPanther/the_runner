// lib/data/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String phoneNumber;
  final String? email;
  final String displayName;
  final String? photoUrl;
  final List<String> roles; // ['user'], ['user','runner'], ['user','admin']
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final List<String> fcmTokens;
  // Overall rating across every completed errand, as a requester or a
  // runner. Updated by the reviews Cloud Function once both sides of a
  // completed errand have rated each other.
  final double averageRating;
  final int totalReviews;

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    this.email,
    required this.displayName,
    this.photoUrl,
    required this.roles,
    required this.createdAt,
    required this.lastActiveAt,
    required this.fcmTokens,
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  static UserModel fromMap(Map<String, dynamic> data, [String? documentId]) {
    return UserModel(
      uid: documentId ?? data["uid"] ?? "",
      phoneNumber: data["phoneNumber"] ?? "",
      email: data["email"],
      displayName: data["displayName"] ?? "",
      photoUrl: data["photoUrl"],
      roles: List<String>.from(data["roles"] ?? []),
      createdAt: _parseTimestamp(data["createdAt"]),
      lastActiveAt: _parseTimestamp(data["lastActiveAt"]),
      fcmTokens: List<String>.from(data["fcmTokens"] ?? []),
      averageRating: (data["averageRating"] as num?)?.toDouble() ?? 0.0,
      totalReviews: (data["totalReviews"] as num?)?.toInt() ?? 0,
    );
  }

  /// The PUBLIC profile (users/{uid}), readable by every signed-in user.
  /// Deliberately leaves out phoneNumber and fcmTokens - those go in the
  /// private account record via [toPrivateMap], and the rules reject a
  /// public profile that contains them.
  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "email": email,
      "displayName": displayName,
      "photoUrl": photoUrl,
      "roles": roles,
      "createdAt": Timestamp.fromDate(createdAt),
      "lastActiveAt": Timestamp.fromDate(lastActiveAt),
      "averageRating": averageRating,
      "totalReviews": totalReviews,
    };
  }

  /// The PRIVATE account record (users/{uid}/private/account): readable
  /// only by the owner and admins.
  Map<String, dynamic> toPrivateMap() {
    return {
      "phoneNumber": phoneNumber,
      "fcmTokens": fcmTokens,
    };
  }

  UserModel cloneWith({
    String? uid,
    String? phoneNumber,
    String? email,
    String? displayName,
    String? photoUrl,
    List<String>? roles,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    List<String>? fcmTokens,
    double? averageRating,
    int? totalReviews,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      roles: roles ?? this.roles,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        phoneNumber,
        email,
        displayName,
        photoUrl,
        roles,
        createdAt,
        lastActiveAt,
        fcmTokens,
        averageRating,
        totalReviews,
      ];

  // Helper getters
  /// Has completed runner onboarding (ID check started). Only runners
  /// can bid on errands.
  bool get isRunner => roles.contains('runner');
  bool get isAdmin => roles.contains('admin');
}