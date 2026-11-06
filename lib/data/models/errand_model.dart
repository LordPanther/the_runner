// lib/data/models/errand_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:the_runner/core/utils/fees.dart';

/// What kind of errand this is. Every type shares one flow; shopping is
/// the only variant (it adds a purchase budget and a receipt step).
enum ErrandType {
  pickupDropoff('pickup_dropoff'),
  queue('queue'),
  admin('admin'),
  shopping('shopping');

  /// The value stored in Firestore. Snake_case to match every other
  /// field, and so the Cloud Functions can compare plain strings.
  final String wire;
  const ErrandType(this.wire);

  static ErrandType fromWire(dynamic value) => ErrandType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => ErrandType.pickupDropoff,
      );
}

/// The errand lifecycle. Money only ever moves on a transition, and
/// every transition after `bidding` is made by a Cloud Function, never
/// by the app itself (the Firestore rules block it).
///
///   draft -> bidding -> accepted -> funded -> inProgress
///         -> proofSubmitted -> completed
///   proofSubmitted -> disputed -> completed (full/partial) | cancelled (refund)
///   bidding | accepted | funded -> cancelled
enum ErrandStatus {
  draft('draft'),
  bidding('bidding'),
  accepted('accepted'),

  /// Requester has paid into TradeSafe escrow. The runner should only
  /// start once an errand reaches this state.
  funded('funded'),
  inProgress('in_progress'),

  /// Runner uploaded proof. The 24-hour auto-release clock is running.
  proofSubmitted('proof_submitted'),
  completed('completed'),

  /// Requester raised a dispute. The auto-release clock is frozen until
  /// it's resolved.
  disputed('disputed'),
  cancelled('cancelled');

  final String wire;
  const ErrandStatus(this.wire);

  static ErrandStatus fromWire(dynamic value) => ErrandStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => ErrandStatus.draft,
      );

  /// Still open for runners to bid on.
  bool get isBiddable => this == ErrandStatus.bidding;

  /// Money is sitting in escrow right now.
  bool get isFundsHeld =>
      this == ErrandStatus.funded ||
      this == ErrandStatus.inProgress ||
      this == ErrandStatus.proofSubmitted ||
      this == ErrandStatus.disputed;

  /// Nothing more will happen to this errand.
  bool get isFinished =>
      this == ErrandStatus.completed || this == ErrandStatus.cancelled;
}

/// Escrow details, written ONLY by Cloud Functions as TradeSafe reports
/// back. The app reads these to show "R105 held safely" and similar.
class EscrowInfo extends Equatable {
  /// TradeSafe's transaction id.
  final String? providerRef;
  final double heldAmount;
  final DateTime? fundedAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;

  const EscrowInfo({
    this.providerRef,
    this.heldAmount = 0,
    this.fundedAt,
    this.releasedAt,
    this.refundedAt,
  });

  static EscrowInfo fromMap(Map<String, dynamic>? data) {
    if (data == null) return const EscrowInfo();
    return EscrowInfo(
      providerRef: data['provider_ref'] as String?,
      heldAmount: (data['held_amount'] as num?)?.toDouble() ?? 0,
      fundedAt: ErrandModel._parseTimestampNullable(data['funded_at']),
      releasedAt: ErrandModel._parseTimestampNullable(data['released_at']),
      refundedAt: ErrandModel._parseTimestampNullable(data['refunded_at']),
    );
  }

  @override
  List<Object?> get props =>
      [providerRef, heldAmount, fundedAt, releasedAt, refundedAt];
}

class ErrandModel extends Equatable {
  final String id;
  final String requesterUid;

  /// Set when the requester accepts a bid.
  final String? runnerUid;
  final ErrandType type;
  final String title;
  final String description;

  // NOTE: like Town Post's jobs, the errand document is readable by
  // every signed-in user, so it only carries an APPROXIMATE pickup
  // location (~1km grid) and a suburb-level label. The real pickup and
  // drop-off addresses live in errands/{id}/private/details, readable
  // only by the requester and the accepted runner.
  final String areaLabel;
  final double lat;
  final double lng;
  final String geohash;

  final DateTime? deadline;
  final DateTime biddingClosesAt;

  // ── Pricing ─────────────────────────────────────────────────
  /// The lowest fee the requester will pay, and the most. Runners bid
  /// anywhere in between.
  final double startingFee;
  final double feeCap;

  /// Locked in when a bid is accepted.
  final double? agreedFee;

  /// A bid at exactly [startingFee] is accepted automatically.
  final bool instantAccept;

  /// Stored per errand (not hard-coded) so a rate change later never
  /// rewrites what an older errand cost.
  final double requesterFeeRate;
  final double runnerFeeRate;

  // ── Shopping only ───────────────────────────────────────────
  final double? purchaseBudget;

  /// What the till receipt actually came to. Unspent budget goes back
  /// to the requester on completion.
  final double? finalPurchaseAmount;

  // ── Lifecycle ───────────────────────────────────────────────
  final ErrandStatus status;

  /// Number of active bids, kept up to date by the syncBidCount Cloud
  /// Function. Null until the first bid changes.
  final int? bidCount;

  /// Set by the server when proof is submitted (+24h). Cleared if a
  /// dispute freezes the clock.
  final DateTime? autoReleaseAt;
  final EscrowInfo escrow;

  /// Who cancelled it: a uid, or "system" when bidding closed with no bids.
  final String? cancelledBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ErrandModel({
    required this.id,
    required this.requesterUid,
    this.runnerUid,
    required this.type,
    required this.title,
    required this.description,
    required this.areaLabel,
    required this.lat,
    required this.lng,
    required this.geohash,
    this.deadline,
    required this.biddingClosesAt,
    required this.startingFee,
    required this.feeCap,
    this.agreedFee,
    this.instantAccept = false,
    this.requesterFeeRate = Fees.defaultRequesterRate,
    this.runnerFeeRate = Fees.defaultRunnerRate,
    this.purchaseBudget,
    this.finalPurchaseAmount,
    required this.status,
    this.bidCount,
    this.autoReleaseAt,
    this.escrow = const EscrowInfo(),
    this.cancelledBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isShopping => type == ErrandType.shopping;

  /// What the requester pays into escrow once a bid is accepted.
  double? get requesterTotal => agreedFee == null
      ? null
      : Fees.requesterTotal(
          agreedFee!,
          purchaseBudget: purchaseBudget ?? 0,
          rate: requesterFeeRate,
        );

  /// What the runner receives for [fee] (defaults to the agreed fee).
  double runnerPayoutFor(double fee) =>
      Fees.runnerPayout(fee, rate: runnerFeeRate);

  /// Bidding closed and nobody bid, so the server took it down.
  bool get isExpiredUnbid =>
      status == ErrandStatus.cancelled && cancelledBy == 'system';

  /// The requester can still change everything and (re)open it for bids:
  /// it expired with no bids, or it's open and nobody has bid yet.
  bool get canEditAndRelist =>
      isExpiredUnbid || (status == ErrandStatus.bidding && (bidCount ?? 0) == 0);

  bool isRequester(String? uid) => uid != null && uid == requesterUid;
  bool isRunner(String? uid) => uid != null && uid == runnerUid;

  static double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return fallback;
  }

  static double? _parseDoubleNullable(dynamic value) =>
      value is num ? value.toDouble() : null;

  static DateTime? _parseTimestampNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static DateTime _parseTimestamp(dynamic value, {DateTime? fallback}) {
    return _parseTimestampNullable(value) ?? fallback ?? DateTime.now();
  }

  // NOTE: snake_case field names throughout, matching the raw Firestore
  // queries in FirebaseErrandRepository and the Cloud Functions. Town
  // Post learned the hard way that a camelCase/snake_case mismatch makes
  // queries silently match nothing.
  static ErrandModel fromMap(Map<String, dynamic> data, [String? documentId]) {
    final createdAt = _parseTimestamp(data['created_at']);
    return ErrandModel(
      id: documentId ?? data['id'] ?? '',
      requesterUid: data['requester_uid'] ?? '',
      runnerUid: data['runner_uid'],
      type: ErrandType.fromWire(data['type']),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      areaLabel: data['area_label'] ?? '',
      lat: _parseDouble(data['lat']),
      lng: _parseDouble(data['lng']),
      geohash: data['geohash'] ?? '',
      deadline: _parseTimestampNullable(data['deadline']),
      biddingClosesAt: _parseTimestamp(
        data['bidding_closes_at'],
        fallback: createdAt.add(const Duration(hours: 24)),
      ),
      startingFee: _parseDouble(data['starting_fee']),
      feeCap: _parseDouble(data['fee_cap']),
      agreedFee: _parseDoubleNullable(data['agreed_fee']),
      instantAccept: data['instant_accept'] ?? false,
      requesterFeeRate: _parseDouble(
        data['requester_fee_rate'],
        fallback: Fees.defaultRequesterRate,
      ),
      runnerFeeRate: _parseDouble(
        data['runner_fee_rate'],
        fallback: Fees.defaultRunnerRate,
      ),
      purchaseBudget: _parseDoubleNullable(data['purchase_budget']),
      finalPurchaseAmount: _parseDoubleNullable(data['final_purchase_amount']),
      status: ErrandStatus.fromWire(data['status']),
      bidCount: (data['bid_count'] as num?)?.toInt(),
      autoReleaseAt: _parseTimestampNullable(data['auto_release_at']),
      escrow: EscrowInfo.fromMap(data['escrow'] as Map<String, dynamic>?),
      cancelledBy: data['cancelled_by'] as String?,
      createdAt: createdAt,
      updatedAt: _parseTimestamp(data['updated_at'], fallback: createdAt),
    );
  }

  /// Fields the APP writes when creating an errand. Server-owned fields
  /// (runner_uid, agreed_fee, escrow, auto_release_at, bid_count,
  /// final_purchase_amount) are deliberately left out: the rules reject
  /// a create that includes them.
  Map<String, dynamic> toCreateMap() {
    return {
      'requester_uid': requesterUid,
      'type': type.wire,
      'title': title,
      'description': description,
      'area_label': areaLabel,
      'lat': lat,
      'lng': lng,
      'geohash': geohash,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'bidding_closes_at': Timestamp.fromDate(biddingClosesAt),
      'starting_fee': startingFee,
      'fee_cap': feeCap,
      'instant_accept': instantAccept,
      'requester_fee_rate': requesterFeeRate,
      'runner_fee_rate': runnerFeeRate,
      if (isShopping) 'purchase_budget': purchaseBudget,
      'status': status.wire,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        requesterUid,
        runnerUid,
        type,
        title,
        description,
        areaLabel,
        lat,
        lng,
        geohash,
        deadline,
        biddingClosesAt,
        startingFee,
        feeCap,
        agreedFee,
        instantAccept,
        requesterFeeRate,
        runnerFeeRate,
        purchaseBudget,
        finalPurchaseAmount,
        status,
        bidCount,
        autoReleaseAt,
        escrow,
        cancelledBy,
        createdAt,
        updatedAt,
      ];
}
