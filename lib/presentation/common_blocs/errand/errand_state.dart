import 'package:equatable/equatable.dart';
import 'package:the_runner/data/models/bid_model.dart';
import 'package:the_runner/data/models/errand_model.dart';

abstract class ErrandState extends Equatable {
  const ErrandState();

  @override
  List<Object?> get props => [];
}

class ErrandInitial extends ErrandState {}

class ErrandLoading extends ErrandState {}

class ErrandLoaded extends ErrandState {
  final ErrandModel errand;

  const ErrandLoaded({required this.errand});

  @override
  List<Object?> get props => [errand];
}

class ErrandsListLoaded extends ErrandState {
  final List<ErrandModel> errands;

  const ErrandsListLoaded({required this.errands});

  @override
  List<Object?> get props => [errands];
}

class ErrandBidsLoaded extends ErrandState {
  final List<BidModel> bids;

  const ErrandBidsLoaded({required this.bids});

  @override
  List<Object?> get props => [bids];
}

class ErrandCreateSuccess extends ErrandState {
  final String errandId;

  const ErrandCreateSuccess({required this.errandId});

  @override
  List<Object?> get props => [errandId];
}

/// A button-triggered action is running (accept, pay, submit proof...).
/// Screens show LoadingOverlay while in this state.
class ErrandActionInProgress extends ErrandState {}

/// An action finished. [messageKey] is a translation key for the
/// confirmation snackbar, e.g. 'bid_placed'.
class ErrandActionSuccess extends ErrandState {
  final String messageKey;

  const ErrandActionSuccess({required this.messageKey});

  @override
  List<Object?> get props => [messageKey];
}

/// TradeSafe checkout is ready to open.
class PaymentLinkReady extends ErrandState {
  final String errandId;
  final String paymentUrl;

  const PaymentLinkReady({required this.errandId, required this.paymentUrl});

  @override
  List<Object?> get props => [errandId, paymentUrl];
}

class ErrandError extends ErrandState {
  final String message;

  const ErrandError({required this.message});

  @override
  List<Object?> get props => [message];
}
