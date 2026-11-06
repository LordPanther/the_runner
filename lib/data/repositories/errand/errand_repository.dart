// lib/data/repositories/errand/errand_repository.dart

import 'dart:io';

import 'package:the_runner/data/models/bid_model.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/data/models/errand_private_details.dart';
import 'package:the_runner/data/models/proof_model.dart';

class CreateErrandRequest {
  final ErrandType type;
  final String title;
  final String description;
  final String areaLabel;
  final ErrandPrivateDetails details;
  final DateTime? deadline;
  final DateTime biddingClosesAt;
  final double startingFee;
  final double feeCap;
  final bool instantAccept;

  /// Shopping errands only.
  final double? purchaseBudget;

  CreateErrandRequest({
    required this.type,
    required this.title,
    required this.description,
    required this.areaLabel,
    required this.details,
    this.deadline,
    required this.biddingClosesAt,
    required this.startingFee,
    required this.feeCap,
    this.instantAccept = false,
    this.purchaseBudget,
  });
}

class SubmitProofRequest {
  final String errandId;
  final List<File> photos;

  /// Shopping errands: the till slip.
  final File? receipt;

  /// Shopping errands: what the receipt came to. Must not exceed the
  /// purchase budget (checked on the server).
  final double? finalPurchaseAmount;
  final String note;

  SubmitProofRequest({
    required this.errandId,
    required this.photos,
    this.receipt,
    this.finalPurchaseAmount,
    this.note = '',
  });
}

/// NOTE: the split between direct Firestore writes and Cloud Function
/// calls is deliberate:
///   - Direct writes (rules-checked): creating an errand, and a runner's
///     own bid. Nothing about money changes.
///   - Cloud Functions: EVERY status change from `accepted` onward, since
///     each one either moves money in TradeSafe or decides who gets it.
abstract class ErrandRepository {
  // ── Errands ─────────────────────────────────────────────────

  /// Create an errand straight into `bidding`. Returns its id.
  Future<String> createErrand(CreateErrandRequest request);

  Future<ErrandModel> getErrandById(String errandId);

  /// Realtime updates, for the errand detail screen.
  Stream<ErrandModel> streamErrand(String errandId);

  /// Edit an errand nobody has bid on and open it for bids again (it
  /// expired with no bids, or it's still open with none yet). Same
  /// errand id; the type can't change. Runs as a Cloud Function.
  Future<void> relistErrand(String errandId, CreateErrandRequest request);

  /// Errands this user posted, newest first.
  Future<List<ErrandModel>> getErrandsByRequester(String requesterUid);

  /// Errands this user is (or was) the accepted runner on, newest first.
  Future<List<ErrandModel>> getErrandsByRunner(String runnerUid);

  /// Errands still open for bids near a location.
  Future<List<ErrandModel>> getOpenErrandsNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    ErrandType? type,
  });

  /// Exact addresses and shopping list. Null when the caller isn't
  /// allowed to see them (the rules decide, not the UI).
  Future<ErrandPrivateDetails?> getPrivateDetails(String errandId);

  // ── Bids (runner side) ──────────────────────────────────────

  Future<void> placeBid({
    required String errandId,
    required double amount,
    required String message,
  });

  Future<void> updateBid({
    required String errandId,
    required double amount,
    required String message,
  });

  Future<void> withdrawBid(String errandId);

  /// Every bid on an errand (requester), or just your own (runner): the
  /// rules only return what the caller may see.
  Future<List<BidModel>> getBidsForErrand(String errandId);

  /// The signed-in runner's bids across all errands.
  Future<List<BidModel>> getMyBids();

  // ── Lifecycle (all Cloud Functions) ─────────────────────────

  /// Requester picks a runner. Locks the price; no money moves yet.
  Future<void> acceptBid(String errandId, String runnerUid);

  /// Starts the TradeSafe payment for an accepted errand. Returns the
  /// checkout URL to open; the errand becomes `funded` when TradeSafe
  /// confirms the money arrived (via webhook, not this call).
  Future<String> startPayment(String errandId);

  /// Runner confirms they're on their way. Only allowed once funded.
  Future<void> startErrand(String errandId);

  /// Runner uploads proof. Starts the 24-hour auto-release clock.
  Future<void> submitProof(SubmitProofRequest request);

  /// Proof the runner has submitted, newest first.
  Future<List<ProofModel>> getProofs(String errandId);

  /// Requester is happy: release the money now.
  Future<void> approveCompletion(String errandId);

  /// Requester isn't happy: freeze the clock and open a dispute.
  Future<void> raiseDispute(String errandId, String reason);

  /// Either side cancels. Refunds automatically if funds were held.
  Future<void> cancelErrand(String errandId, {String reason = ''});
}
