// lib/data/repositories/errand/firebase_errand_repository.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:the_runner/data/models/bid_model.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/data/models/errand_private_details.dart';
import 'package:the_runner/data/models/proof_model.dart';
import 'package:the_runner/data/repositories/errand/errand_repository.dart';
import 'package:the_runner/data/services/block_list.dart';
import 'package:the_runner/data/services/geohash_service.dart';
import 'package:the_runner/data/services/image_compression_service.dart';
import 'package:the_runner/data/services/location_privacy.dart';
import 'package:the_runner/data/services/nearby_query.dart';

// NOTE: this repository never creates notifications. Every
// user-to-user notification (new bid, bid accepted, funded, proof
// submitted, released, disputed, cancelled) is created by Cloud
// Functions reacting to the change itself - see functions/src/index.ts.
class FirebaseErrandRepository implements ErrandRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GeohashService _geohashService = GeohashService();

  CollectionReference<Map<String, dynamic>> get _errands =>
      _firestore.collection('errands');

  String get _uid {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    return uid;
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    await _functions.httpsCallable(name).call<Map<String, dynamic>>(data);
  }

  // ── Errands ─────────────────────────────────────────────────

  @override
  Future<String> createErrand(CreateErrandRequest request) async {
    try {
      if (request.feeCap < request.startingFee) {
        throw Exception('The cap must be at least the starting fee');
      }
      final errandRef = _errands.doc();

      // Public document: approximate pickup only (~1km grid).
      final approxLat = approximateCoordinate(request.details.pickupLat);
      final approxLng = approximateCoordinate(request.details.pickupLng);
      final now = DateTime.now();

      final errand = ErrandModel(
        id: errandRef.id,
        requesterUid: _uid,
        type: request.type,
        title: request.title,
        description: request.description,
        areaLabel: request.areaLabel,
        lat: approxLat,
        lng: approxLng,
        geohash: _geohashService.encode(approxLat, approxLng),
        deadline: request.deadline,
        biddingClosesAt: request.biddingClosesAt,
        startingFee: request.startingFee,
        feeCap: request.feeCap,
        instantAccept: request.instantAccept,
        purchaseBudget:
            request.type == ErrandType.shopping ? request.purchaseBudget : null,
        status: ErrandStatus.bidding,
        createdAt: now,
        updatedAt: now,
      );

      // One atomic batch: an errand never exists without its private
      // details, or the other way round.
      final batch = _firestore.batch();
      batch.set(errandRef, errand.toCreateMap());
      batch.set(
        errandRef.collection('private').doc('details'),
        request.details.toMap(),
      );
      await batch.commit();

      return errandRef.id;
    } catch (e) {
      throw Exception('Failed to create errand: $e');
    }
  }

  @override
  Future<void> relistErrand(String errandId, CreateErrandRequest request) async {
    if (request.feeCap < request.startingFee) {
      throw Exception('The cap must be at least the starting fee');
    }
    await _call('relistErrand', {
      'errandId': errandId,
      'title': request.title,
      'description': request.description,
      'areaLabel': request.areaLabel,
      'startingFee': request.startingFee,
      'feeCap': request.feeCap,
      'instantAccept': request.instantAccept,
      'purchaseBudget': ?request.purchaseBudget,
      'deadlineMs': ?request.deadline?.millisecondsSinceEpoch,
      'biddingClosesAtMs': request.biddingClosesAt.millisecondsSinceEpoch,
      'details': request.details.toMap(),
    });
  }

  @override
  Future<ErrandModel> getErrandById(String errandId) async {
    try {
      final doc = await _errands.doc(errandId).get();
      if (!doc.exists) throw Exception('Errand not found');
      return ErrandModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get errand: $e');
    }
  }

  @override
  Stream<ErrandModel> streamErrand(String errandId) {
    return _errands.doc(errandId).snapshots().map((doc) {
      if (!doc.exists) throw Exception('Errand not found');
      return ErrandModel.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Future<List<ErrandModel>> getErrandsByRequester(String requesterUid) async {
    try {
      // Needs the composite index errands: requester_uid + created_at.
      final snapshot = await _errands
          .where('requester_uid', isEqualTo: requesterUid)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();
      return snapshot.docs
          .map((doc) => ErrandModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get your errands: $e');
    }
  }

  @override
  Future<List<ErrandModel>> getErrandsByRunner(String runnerUid) async {
    try {
      // Needs the composite index errands: runner_uid + created_at.
      final snapshot = await _errands
          .where('runner_uid', isEqualTo: runnerUid)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();
      return snapshot.docs
          .map((doc) => ErrandModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get your runs: $e');
    }
  }

  @override
  Future<List<ErrandModel>> getOpenErrandsNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    ErrandType? type,
  }) async {
    try {
      // Bidding errands in the 3x3 geohash cells around the runner, then
      // the exact distance check below. Needs the composite index
      // errands: status + geohash. Type is filtered on the phone so no
      // extra index is needed.
      final docs = await queryNearby(
        base: _errands.where('status', isEqualTo: ErrandStatus.bidding.wire),
        field: 'geohash',
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );

      final uid = _firebaseAuth.currentUser?.uid;
      final now = DateTime.now();
      final all = docs.map((doc) => ErrandModel.fromMap(doc.data(), doc.id)).toList();

      final ofType = all.where((e) => type == null || e.type == type).toList();
      // Your own errands live in My Errands, not the feed.
      final notMine = ofType.where((e) => e.requesterUid != uid).toList();
      // Bidding closed but the server hasn't caught up yet.
      final open = notMine.where((e) => e.biddingClosesAt.isAfter(now)).toList();
      var errands = open
          .where((e) =>
              GeohashService.distanceMeters(lat, lng, e.lat, e.lng) <=
              radiusKm * 1000)
          .toList();

      // Why an errand didn't show: how many survive each filter.
      debugPrint('[ErrandFeed] at ($lat, $lng) radius ${radiusKm}km: '
          'fetched ${all.length} -> type ${ofType.length} -> not mine ${notMine.length} '
          '-> still open ${open.length} -> in range ${errands.length}');
      for (final e in all) {
        final km = GeohashService.distanceMeters(lat, lng, e.lat, e.lng) / 1000;
        debugPrint('[ErrandFeed]   "${e.title}" ${km.toStringAsFixed(1)}km '
            'mine=${e.requesterUid == uid} closes=${e.biddingClosesAt}');
      }

      // Closest deadline first: an errand due in an hour matters more
      // than one due next week.
      errands.sort((a, b) => a.biddingClosesAt.compareTo(b.biddingClosesAt));

      return BlockList.instance.withoutBlocked(errands, (e) => e.requesterUid);
    } catch (e) {
      throw Exception('Failed to get nearby errands: $e');
    }
  }

  @override
  Future<ErrandPrivateDetails?> getPrivateDetails(String errandId) async {
    try {
      final doc = await _errands
          .doc(errandId)
          .collection('private')
          .doc('details')
          .get();
      if (!doc.exists) return null;
      return ErrandPrivateDetails.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      // permission-denied is the EXPECTED answer for anyone the rules
      // don't allow to see this - not an error worth surfacing.
      if (e.code == 'permission-denied') return null;
      throw Exception('Failed to load errand details: $e');
    }
  }

  // ── Bids ────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _bidRef(String errandId, String runnerUid) =>
      _errands.doc(errandId).collection('bids').doc(runnerUid);

  @override
  Future<void> placeBid({
    required String errandId,
    required double amount,
    required String message,
  }) async {
    try {
      final errand = await getErrandById(errandId);
      if (!errand.status.isBiddable) {
        throw Exception('This errand is no longer open');
      }
      if (amount < errand.startingFee || amount > errand.feeCap) {
        throw Exception('Bid must be between the starting fee and the cap');
      }
      final ref = _bidRef(errandId, _uid);
      final existing = await ref.get();
      if (existing.exists &&
          BidStatus.fromWire(existing.data()?['status']) == BidStatus.pending) {
        throw Exception('You already placed a bid on this errand');
      }
      final bid = BidModel(
        errandId: errandId,
        runnerUid: _uid,
        amount: amount,
        message: message,
        status: BidStatus.pending,
        createdAt: DateTime.now(),
      );
      await ref.set(bid.toCreateMap());
    } catch (e) {
      throw Exception('Failed to place bid: $e');
    }
  }

  @override
  Future<void> updateBid({
    required String errandId,
    required double amount,
    required String message,
  }) async {
    try {
      await _bidRef(errandId, _uid).update({
        'amount': amount,
        'message': message,
        'edited_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update bid: $e');
    }
  }

  @override
  Future<void> withdrawBid(String errandId) async {
    try {
      // Deleted outright so the runner can bid again later if they like.
      await _bidRef(errandId, _uid).delete();
    } catch (e) {
      throw Exception('Failed to withdraw bid: $e');
    }
  }

  @override
  Future<List<BidModel>> getBidsForErrand(String errandId) async {
    try {
      final snapshot = await _errands
          .doc(errandId)
          .collection('bids')
          .orderBy('amount')
          .get();
      final bids = snapshot.docs
          .map((doc) => BidModel.fromMap(doc.data(), errandId, doc.id))
          .toList();
      return BlockList.instance.withoutBlocked(bids, (b) => b.runnerUid);
    } catch (e) {
      throw Exception('Failed to get bids: $e');
    }
  }

  @override
  Future<List<BidModel>> getMyBids() async {
    try {
      // Collection group query across every errand's bids. Needs the
      // collection-group index bids: runner_uid + created_at.
      final snapshot = await _firestore
          .collectionGroup('bids')
          .where('runner_uid', isEqualTo: _uid)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();
      return snapshot.docs
          .map((doc) => BidModel.fromMap(
                doc.data(),
                doc.reference.parent.parent!.id,
                doc.id,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to get your bids: $e');
    }
  }

  // ── Lifecycle ───────────────────────────────────────────────

  @override
  Future<void> acceptBid(String errandId, String runnerUid) =>
      _call('acceptBid', {'errandId': errandId, 'runnerUid': runnerUid});

  @override
  Future<String> startPayment(String errandId) async {
    final result = await _functions
        .httpsCallable('startPayment')
        .call<Map<String, dynamic>>({'errandId': errandId});
    final url = result.data['paymentUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Payment link unavailable, please try again');
    }
    return url;
  }

  @override
  Future<void> startErrand(String errandId) =>
      _call('startErrand', {'errandId': errandId});

  @override
  Future<void> submitProof(SubmitProofRequest request) async {
    try {
      final folder = 'errands/${request.errandId}/proof';
      final photoUrls = <String>[];
      for (final photo in request.photos) {
        photoUrls.add(await _upload(folder, photo));
      }
      final receiptUrl =
          request.receipt == null ? null : await _upload(folder, request.receipt!);

      await _call('submitProof', {
        'errandId': request.errandId,
        'photoUrls': photoUrls,
        'receiptUrl': ?receiptUrl,
        'finalPurchaseAmount': ?request.finalPurchaseAmount,
        'note': request.note,
      });
    } catch (e) {
      throw Exception('Failed to submit proof: $e');
    }
  }

  Future<String> _upload(String folder, File file) async {
    final compressed = await ImageCompressionService.compressImage(file);
    final name = '${DateTime.now().millisecondsSinceEpoch}_$_uid.jpg';
    final ref = _storage.ref('$folder/$name');
    await ref.putFile(compressed, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  @override
  Future<List<ProofModel>> getProofs(String errandId) async {
    try {
      final snapshot = await _errands
          .doc(errandId)
          .collection('proofs')
          .orderBy('created_at', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ProofModel.fromMap(doc.data(), doc.id))
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return const [];
      throw Exception('Failed to load proof: $e');
    }
  }

  @override
  Future<void> approveCompletion(String errandId) =>
      _call('approveCompletion', {'errandId': errandId});

  @override
  Future<void> raiseDispute(String errandId, String reason) =>
      _call('raiseDispute', {'errandId': errandId, 'reason': reason});

  @override
  Future<void> cancelErrand(String errandId, {String reason = ''}) =>
      _call('cancelErrand', {'errandId': errandId, 'reason': reason});
}
