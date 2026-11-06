import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/data/repositories/repository.dart';
import 'package:the_runner/data/services/block_list.dart';
import 'package:the_runner/data/services/errand_changes.dart';
import 'package:the_runner/presentation/common_blocs/errand/errand_event.dart';
import 'package:the_runner/presentation/common_blocs/errand/errand_state.dart';

/// Fired when the user blocks or unblocks someone.
class _BlockListChanged extends ErrandEvent {
  const _BlockListChanged();
}

/// NOTE: like Town Post's JobBloc, this is never a global singleton.
/// Each screen gets its own instance (see router.dart and
/// bottom_navigation.dart), so the feed's list can't be overwritten by
/// My Errands loading in another tab.
///
/// Detail screens keep the errand stream running while actions fire:
/// an action emits ErrandActionInProgress/Success, then the next
/// snapshot from Firestore emits ErrandLoaded with the new status.
class ErrandBloc extends Bloc<ErrandEvent, ErrandState> {
  final ErrandRepository _repository = AppRepository.errandRepository;

  ErrandBloc() : super(ErrandInitial()) {
    // restartable(): opening a second errand cancels the live updates
    // for the first, so an old errand can't replace the one on screen.
    on<StreamErrand>(_onStreamErrand, transformer: restartable());
    on<LoadOpenErrandsNearby>(_onLoadNearby, transformer: restartable());
    on<LoadMyPostedErrands>(_onLoadMyPosted, transformer: restartable());
    on<LoadMyRuns>(_onLoadMyRuns, transformer: restartable());
    on<LoadBidsForErrand>(_onLoadBids, transformer: restartable());

    // droppable(): a second tap while the first is still running is
    // ignored. Stops the "tapped Post 5 times, got 5 errands" bug Town
    // Post hit with jobs.
    on<CreateErrand>(_onCreateErrand, transformer: droppable());
    on<RelistErrand>(_onRelist, transformer: droppable());
    on<PlaceBid>(_onPlaceBid, transformer: droppable());
    on<UpdateBid>(_onUpdateBid, transformer: droppable());
    on<WithdrawBid>(_onWithdrawBid, transformer: droppable());
    on<AcceptBid>(_onAcceptBid, transformer: droppable());
    on<StartPayment>(_onStartPayment, transformer: droppable());
    on<StartErrand>(_onStartErrand, transformer: droppable());
    on<SubmitProof>(_onSubmitProof, transformer: droppable());
    on<ApproveCompletion>(_onApprove, transformer: droppable());
    on<RaiseDispute>(_onRaiseDispute, transformer: droppable());
    on<CancelErrand>(_onCancel, transformer: droppable());

    on<_BlockListChanged>(_onBlockListChanged);
    BlockList.instance.blocked.addListener(_blockListener);
  }

  void _blockListener() {
    if (!isClosed) add(const _BlockListChanged());
  }

  @override
  Future<void> close() {
    BlockList.instance.blocked.removeListener(_blockListener);
    return super.close();
  }

  // Only errands still in bidding are hidden: one already under way
  // with that person stays visible so it can still be finished.
  void _onBlockListChanged(_BlockListChanged event, Emitter<ErrandState> emit) {
    final current = state;
    if (current is! ErrandsListLoaded) return;
    final blocks = BlockList.instance;
    final visible = current.errands
        .where((e) => !e.status.isBiddable || !blocks.isBlocked(e.requesterUid))
        .toList();
    if (visible.length != current.errands.length) {
      emit(ErrandsListLoaded(errands: visible));
    }
  }

  // ── Loading ─────────────────────────────────────────────────

  Future<void> _onStreamErrand(StreamErrand event, Emitter<ErrandState> emit) async {
    emit(ErrandLoading());
    try {
      await emit.forEach<ErrandModel>(
        _repository.streamErrand(event.errandId),
        onData: (errand) => ErrandLoaded(errand: errand),
        onError: (e, _) => ErrandError(message: e.toString()),
      );
    } catch (e) {
      // Without this an uncaught error left the bloc stuck on
      // ErrandLoading with nothing on screen.
      if (!isClosed) emit(ErrandError(message: e.toString()));
    }
  }

  Future<void> _onLoadNearby(LoadOpenErrandsNearby event, Emitter<ErrandState> emit) =>
      _loadList(emit, () => _repository.getOpenErrandsNearby(
            lat: event.lat,
            lng: event.lng,
            radiusKm: event.radiusKm,
            type: event.type,
          ));

  Future<void> _onLoadMyPosted(LoadMyPostedErrands event, Emitter<ErrandState> emit) =>
      _loadList(emit, () => _repository.getErrandsByRequester(event.userUid));

  Future<void> _onLoadMyRuns(LoadMyRuns event, Emitter<ErrandState> emit) =>
      _loadList(emit, () => _repository.getErrandsByRunner(event.userUid));

  Future<void> _loadList(
    Emitter<ErrandState> emit,
    Future<List<ErrandModel>> Function() load,
  ) async {
    emit(ErrandLoading());
    try {
      emit(ErrandsListLoaded(errands: await load()));
    } catch (e) {
      emit(ErrandError(message: e.toString()));
    }
  }

  Future<void> _onLoadBids(LoadBidsForErrand event, Emitter<ErrandState> emit) async {
    try {
      final bids = await _repository.getBidsForErrand(event.errandId);
      emit(ErrandBidsLoaded(bids: bids));
    } catch (e) {
      emit(ErrandError(message: e.toString()));
    }
  }

  // ── Actions ─────────────────────────────────────────────────

  /// Runs [action] between ErrandActionInProgress and
  /// ErrandActionSuccess(messageKey), or ErrandError on failure.
  Future<void> _act(
    Emitter<ErrandState> emit,
    String messageKey,
    Future<void> Function() action,
  ) async {
    emit(ErrandActionInProgress());
    try {
      await action();
      emit(ErrandActionSuccess(messageKey: messageKey));
      ErrandChanges.notify();
    } catch (e) {
      emit(ErrandError(message: e.toString()));
    }
  }

  Future<void> _onCreateErrand(CreateErrand event, Emitter<ErrandState> emit) async {
    emit(ErrandActionInProgress());
    try {
      final id = await _repository.createErrand(event.request);
      emit(ErrandCreateSuccess(errandId: id));
      ErrandChanges.notify();
    } catch (e) {
      emit(ErrandError(message: e.toString()));
    }
  }

  Future<void> _onRelist(RelistErrand event, Emitter<ErrandState> emit) =>
      _act(emit, 'errand_relisted', () => _repository.relistErrand(event.errandId, event.request));

  Future<void> _onPlaceBid(PlaceBid event, Emitter<ErrandState> emit) =>
      _act(emit, 'bid_placed', () => _repository.placeBid(
            errandId: event.errandId,
            amount: event.amount,
            message: event.message,
          ));

  Future<void> _onUpdateBid(UpdateBid event, Emitter<ErrandState> emit) =>
      _act(emit, 'bid_updated', () => _repository.updateBid(
            errandId: event.errandId,
            amount: event.amount,
            message: event.message,
          ));

  Future<void> _onWithdrawBid(WithdrawBid event, Emitter<ErrandState> emit) =>
      _act(emit, 'bid_withdrawn', () => _repository.withdrawBid(event.errandId));

  Future<void> _onAcceptBid(AcceptBid event, Emitter<ErrandState> emit) =>
      _act(emit, 'bid_accepted', () => _repository.acceptBid(event.errandId, event.runnerUid));

  Future<void> _onStartPayment(StartPayment event, Emitter<ErrandState> emit) async {
    emit(ErrandActionInProgress());
    try {
      final url = await _repository.startPayment(event.errandId);
      emit(PaymentLinkReady(errandId: event.errandId, paymentUrl: url));
    } catch (e) {
      emit(ErrandError(message: e.toString()));
    }
  }

  Future<void> _onStartErrand(StartErrand event, Emitter<ErrandState> emit) =>
      _act(emit, 'errand_started', () => _repository.startErrand(event.errandId));

  Future<void> _onSubmitProof(SubmitProof event, Emitter<ErrandState> emit) =>
      _act(emit, 'proof_submitted', () => _repository.submitProof(event.request));

  Future<void> _onApprove(ApproveCompletion event, Emitter<ErrandState> emit) =>
      _act(emit, 'errand_approved', () => _repository.approveCompletion(event.errandId));

  Future<void> _onRaiseDispute(RaiseDispute event, Emitter<ErrandState> emit) =>
      _act(emit, 'dispute_raised', () => _repository.raiseDispute(event.errandId, event.reason));

  Future<void> _onCancel(CancelErrand event, Emitter<ErrandState> emit) =>
      _act(emit, 'errand_cancelled', () => _repository.cancelErrand(event.errandId, reason: event.reason));
}
