// lib/data/services/demo_account.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A fixed location for accounts used by Google Play's app reviewers.
///
/// Reviewers sign in with the Firebase test phone number from outside
/// South Africa, so "near me" would be their own city and every list
/// would be empty, which looks like a broken app and gets rejected.
///
/// To make an account a demo account, create (in the Firebase Console,
/// never from the app) a document at demo_accounts/{uid} with:
///   latitude  (number)  e.g. -26.2041
///   longitude (number)  e.g. 28.0473
///   label     (string)  optional, shown in logs only
///
/// While signed in as that account, the app uses this location instead
/// of GPS (and doesn't need location permission). Every other account
/// is unaffected: the document simply doesn't exist for them.
class DemoAccount {
  DemoAccount._();
  static final DemoAccount instance = DemoAccount._();

  Position? _position;

  /// The fixed location, or null for normal accounts.
  Position? get position => _position;
  bool get isActive => _position != null;

  /// Load after sign-in. Safe to call more than once.
  Future<void> load() async {
    _position = null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('demo_accounts')
          .doc(uid)
          .get();
      final data = snap.data();
      final lat = (data?['latitude'] as num?)?.toDouble();
      final lng = (data?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      _position = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      debugPrint('Demo account: fixed location ${data?['label'] ?? ''}');
    } catch (e) {
      debugPrint('DemoAccount.load failed: $e');
    }
  }

  /// Forget on sign-out, so the next account uses real GPS.
  void clear() => _position = null;
}
