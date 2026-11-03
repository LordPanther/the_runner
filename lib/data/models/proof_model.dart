// lib/data/models/proof_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// What the runner submitted to show the errand is done. Written by the
/// submitProof Cloud Function to errands/{errandId}/proofs/{proofId};
/// readable by the requester and the runner (and admins for disputes).
class ProofModel extends Equatable {
  final String id;
  final String runnerUid;
  final List<String> photoUrls;
  final String? receiptUrl;
  final double? finalPurchaseAmount;
  final String note;
  final DateTime createdAt;

  const ProofModel({
    required this.id,
    required this.runnerUid,
    required this.photoUrls,
    this.receiptUrl,
    this.finalPurchaseAmount,
    this.note = '',
    required this.createdAt,
  });

  static ProofModel fromMap(Map<String, dynamic> data, String id) {
    final created = data['created_at'];
    return ProofModel(
      id: id,
      runnerUid: data['runner_uid'] ?? '',
      photoUrls: (data['photo_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      receiptUrl: data['receipt_url'] as String?,
      finalPurchaseAmount: (data['final_purchase_amount'] as num?)?.toDouble(),
      note: data['note'] ?? '',
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, runnerUid, photoUrls, receiptUrl, finalPurchaseAmount, note, createdAt];
}
