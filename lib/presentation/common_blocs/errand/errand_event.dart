import 'package:equatable/equatable.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/data/repositories/errand/errand_repository.dart';

abstract class ErrandEvent extends Equatable {
  const ErrandEvent();

  @override
  List<Object?> get props => [];
}

// ── Loading ───────────────────────────────────────────────────

class StreamErrand extends ErrandEvent {
  final String errandId;

  const StreamErrand(this.errandId);

  @override
  List<Object?> get props => [errandId];
}

class LoadOpenErrandsNearby extends ErrandEvent {
  final double lat;
  final double lng;
  final double radiusKm;
  final ErrandType? type;

  const LoadOpenErrandsNearby({
    required this.lat,
    required this.lng,
    required this.radiusKm,
    this.type,
  });

  @override
  List<Object?> get props => [lat, lng, radiusKm, type];
}

class LoadMyPostedErrands extends ErrandEvent {
  final String userUid;

  const LoadMyPostedErrands(this.userUid);

  @override
  List<Object?> get props => [userUid];
}

class LoadMyRuns extends ErrandEvent {
  final String userUid;

  const LoadMyRuns(this.userUid);

  @override
  List<Object?> get props => [userUid];
}

class LoadBidsForErrand extends ErrandEvent {
  final String errandId;

  const LoadBidsForErrand(this.errandId);

  @override
  List<Object?> get props => [errandId];
}

// ── Requester ────────────────────────────────────────────────

class CreateErrand extends ErrandEvent {
  final CreateErrandRequest request;

  const CreateErrand(this.request);

  @override
  List<Object?> get props => [request];
}

class AcceptBid extends ErrandEvent {
  final String errandId;
  final String runnerUid;

  const AcceptBid({required this.errandId, required this.runnerUid});

  @override
  List<Object?> get props => [errandId, runnerUid];
}

class StartPayment extends ErrandEvent {
  final String errandId;

  const StartPayment(this.errandId);

  @override
  List<Object?> get props => [errandId];
}

class ApproveCompletion extends ErrandEvent {
  final String errandId;

  const ApproveCompletion(this.errandId);

  @override
  List<Object?> get props => [errandId];
}

class RaiseDispute extends ErrandEvent {
  final String errandId;
  final String reason;

  const RaiseDispute({required this.errandId, required this.reason});

  @override
  List<Object?> get props => [errandId, reason];
}

class CancelErrand extends ErrandEvent {
  final String errandId;
  final String reason;

  const CancelErrand({required this.errandId, this.reason = ''});

  @override
  List<Object?> get props => [errandId, reason];
}

// ── Runner ───────────────────────────────────────────────────

class PlaceBid extends ErrandEvent {
  final String errandId;
  final double amount;
  final String message;

  const PlaceBid({
    required this.errandId,
    required this.amount,
    required this.message,
  });

  @override
  List<Object?> get props => [errandId, amount, message];
}

class UpdateBid extends ErrandEvent {
  final String errandId;
  final double amount;
  final String message;

  const UpdateBid({
    required this.errandId,
    required this.amount,
    required this.message,
  });

  @override
  List<Object?> get props => [errandId, amount, message];
}

class WithdrawBid extends ErrandEvent {
  final String errandId;

  const WithdrawBid(this.errandId);

  @override
  List<Object?> get props => [errandId];
}

class StartErrand extends ErrandEvent {
  final String errandId;

  const StartErrand(this.errandId);

  @override
  List<Object?> get props => [errandId];
}

class SubmitProof extends ErrandEvent {
  final SubmitProofRequest request;

  const SubmitProof(this.request);

  @override
  List<Object?> get props => [request];
}
