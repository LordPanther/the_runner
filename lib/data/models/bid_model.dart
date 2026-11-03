// lib/data/models/bid_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum BidStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  withdrawn('withdrawn');

  final String wire;
  const BidStatus(this.wire);

  // NOTE: every status listed explicitly. Town Post once parsed
  // "withdrawn" as pending because it was missing from a switch.
  static BidStatus fromWire(dynamic value) => BidStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => BidStatus.pending,
      );
}

/// A runner's offer on an errand. Stored at errands/{errandId}/bids/{runnerUid}:
/// using the runner's uid as the document id makes "one bid per runner
/// per errand" a fact of the data shape rather than a check that can be
/// raced.
class BidModel extends Equatable {
  final String errandId;
  final String runnerUid;

  /// Gross fee the runner is asking for. The app shows "you'll receive
  /// R95" next to it; the 5% comes off on payout.
  final double amount;
  final String message;
  final BidStatus status;
  final DateTime createdAt;

  /// Set when the runner edits a pending bid, so the requester can see
  /// it changed after it first came in.
  final DateTime? editedAt;

  const BidModel({
    required this.errandId,
    required this.runnerUid,
    required this.amount,
    required this.message,
    required this.status,
    required this.createdAt,
    this.editedAt,
  });

  /// The bid's document id is the runner's uid.
  String get id => runnerUid;

  static DateTime? _parseTimestampNullable(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static BidModel fromMap(Map<String, dynamic> data, String errandId, String runnerUid) {
    return BidModel(
      errandId: errandId,
      runnerUid: runnerUid,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      message: data['message'] ?? '',
      status: BidStatus.fromWire(data['status']),
      createdAt: _parseTimestampNullable(data['created_at']) ?? DateTime.now(),
      editedAt: _parseTimestampNullable(data['edited_at']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'runner_uid': runnerUid,
      'amount': amount,
      'message': message,
      'status': BidStatus.pending.wire,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props =>
      [errandId, runnerUid, amount, message, status, createdAt, editedAt];
}
