// lib/data/services/block_list.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// The signed-in user's blocked people, kept in memory so every list in
/// the app can hide them without an extra read.
///
/// Stored privately at users/{uid}/private/blocks as {uids: [...]}: only
/// the owner can read or change it (firestore.rules), so a blocked
/// person never finds out they were blocked.
///
/// What blocking does: the blocked person's errands and bids
/// are hidden from YOU. It's one-way and private,
/// which is what Google Play's user-generated content policy asks for.
class BlockList {
  BlockList._();
  static final BlockList instance = BlockList._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current blocked uids. Screens can listen to rebuild when it changes.
  final ValueNotifier<Set<String>> blocked = ValueNotifier<Set<String>>(<String>{});

  DocumentReference<Map<String, dynamic>>? _ref() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('private').doc('blocks');
  }

  /// Load after sign-in. Safe to call more than once.
  Future<void> load() async {
    final ref = _ref();
    if (ref == null) return;
    try {
      final snap = await ref.get();
      blocked.value = Set<String>.from(snap.data()?['uids'] ?? const []);
    } catch (e) {
      debugPrint('BlockList.load failed: $e');
    }
  }

  /// Forget everything on sign-out, so the next account starts clean.
  void clear() => blocked.value = <String>{};

  bool isBlocked(String? uid) => uid != null && blocked.value.contains(uid);

  /// Removes items whose owner is blocked.
  List<T> withoutBlocked<T>(List<T> items, String? Function(T item) ownerOf) {
    if (blocked.value.isEmpty) return items;
    return items.where((item) => !isBlocked(ownerOf(item))).toList();
  }

  Future<void> block(String uid) async {
    final ref = _ref();
    if (ref == null || uid == _auth.currentUser?.uid) return;
    await ref.set({'uids': FieldValue.arrayUnion([uid])}, SetOptions(merge: true));
    blocked.value = {...blocked.value, uid};
  }

  Future<void> unblock(String uid) async {
    final ref = _ref();
    if (ref == null) return;
    await ref.set({'uids': FieldValue.arrayRemove([uid])}, SetOptions(merge: true));
    blocked.value = {...blocked.value}..remove(uid);
  }
}
