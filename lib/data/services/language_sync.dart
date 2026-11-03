// lib/data/services/language_sync.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:the_runner/data/local/pref.dart';

/// Saves the app language to users/{uid}/private/settings so Cloud
/// Functions can write push notifications in it (en or zu). Called
/// after sign-in and whenever the language is changed in Settings.
class LanguageSync {
  LanguageSync._();

  static Future<void> save([String? languageCode]) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final code = languageCode ?? LocalPref.getString('language') ?? 'en';
    if (code != 'en' && code != 'zu') return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('settings')
          // merge: keeps the errand_alerts setting in the same document.
          .set({'language': code}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('LanguageSync.save failed: $e');
    }
  }

  static DocumentReference<Map<String, dynamic>>? _ref() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('settings');
  }

  /// Whether this runner wants a push for each new errand posted near
  /// them (notifyRunnersOnErrandCreated). On unless turned off.
  static Future<bool> errandAlertsEnabled() async {
    try {
      final snap = await _ref()?.get();
      return snap?.data()?['errand_alerts'] != false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setErrandAlerts(bool enabled) async {
    await _ref()?.set({'errand_alerts': enabled}, SetOptions(merge: true));
  }
}
