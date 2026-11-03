import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:the_runner/data/services/image_compression_service.dart';
// lib/data/repositories/auth_repository_impl.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:the_runner/data/models/user_model.dart';
import 'package:the_runner/data/repositories/auth/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Android can verify the number by itself (it reads the SMS, or the
  // phone number is already trusted) without the user typing a code.
  // That can happen before OR after the code screen has opened, so the
  // result is announced on this stream and AuthBloc signs the user in
  // from wherever they are.
  final StreamController<UserModel> _autoSignIns =
      StreamController<UserModel>.broadcast();

  @override
  Stream<UserModel> get autoSignIns => _autoSignIns.stream;

  @override
  Future<String> signInWithPhone(String phoneNumber) async {
    final completer = Completer<String>();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          // Android verified the number by itself - no code to type.
          // Previously this signed in but never created the user's
          // profile and left them on the code screen with an empty
          // verification id, so any code they typed failed and every
          // restart sent them back to login.
          try {
            final result = await _firebaseAuth.signInWithCredential(credential);
            final user = await _loadOrCreateProfile(result.user!);
            _autoSignIns.add(user);
            // '' tells AuthBloc "no code screen needed".
            if (!completer.isCompleted) completer.complete('');
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(Exception('Automatic sign-in failed: $e'));
            }
          }
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) {
            completer.completeError(
              // The code (e.g. invalid-phone-number, too-many-requests) is kept
              // in the message so the app can show a friendly explanation.
              Exception('Verification failed [${error.code}]: ${error.message}'),
            );
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          // Only relevant if codeSent never fired first - safety net so
          // the Future doesn't hang forever.
          if (!completer.isCompleted) completer.complete(verificationId);
        },
      );

      return await completer.future;
    } on FirebaseAuthException catch (e) {
      throw Exception('Phone sign-in failed [${e.code}]: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  @override
  Future<UserModel> verifyOtp(String verificationId, String otpCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpCode,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      return await _loadOrCreateProfile(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      throw Exception('OTP verification failed [${e.code}]: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// After any successful sign-in (typed code or Android's automatic
  /// verification): creates the profile on first sign-in, otherwise
  /// loads it. One place, so both paths behave the same.
  Future<UserModel> _loadOrCreateProfile(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      // Create new user document
      final newUser = UserModel(
        uid: user.uid,
        phoneNumber: user.phoneNumber!,
        email: user.email,
        displayName: user.displayName ?? '',
        photoUrl: user.photoURL,
        roles: ['user'],
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        fcmTokens: [],
      );

      // Public profile and private account record in one batch, so a
      // new account never exists with only half of it.
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(user.uid), newUser.toMap());
      batch.set(_privateRef(user.uid), newUser.toPrivateMap());
      await batch.commit();

      return newUser;
    }

    // Update last active
    await _firestore.collection('users').doc(user.uid).update({
      'last_active_at': Timestamp.fromDate(DateTime.now()),
    });

    return _withPrivate(user.uid, userDoc.data()!);
  }

  @override
  Future<void> signOut() async {
    // Stop push notifications to THIS phone only. Previously this wrote
    // 'fcm_tokens', but the real field is 'fcmTokens' (see UserModel), so
    // a logged-out phone kept receiving the user's pushes. It also wiped
    // every token, which would have logged the user's OTHER phones out
    // of notifications too.
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _privateRef(user.uid).update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
        }
      } catch (_) {
        // Best effort: never let a token clean-up failure (offline,
        // profile already deleted) stop the user from signing out.
      }
    }

    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      // Deletion runs on the server: it removes data across many
      // collections and other people's jobs, which the rules (rightly)
      // never let a phone do. The uid comes from the sign-in token.
      await FirebaseFunctions.instance
          .httpsCallable(
            'deleteAccount',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
          )
          .call<Map<String, dynamic>>({'confirm': 'DELETE'});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Could not delete your account');
    }

    // The account no longer exists on the server - just clear this
    // phone's session. (signOut()'s token clean-up would fail anyway,
    // since the profile is already gone.)
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
  }

  @override
  Stream<UserModel?> get currentUserStream {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) return null;

      return _withPrivate(firebaseUser.uid, userDoc.data()!);
    });
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    final userDoc = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (!userDoc.exists) return null;

    return _withPrivate(firebaseUser.uid, userDoc.data()!);
  }

  /// Someone's PUBLIC profile. For anyone other than yourself the phone
  /// number comes back empty - use [getContactPhone] for that.
  @override
  Future<UserModel?> getUserById(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();

    if (!userDoc.exists) return null;

    if (uid == _firebaseAuth.currentUser?.uid) {
      return _withPrivate(uid, userDoc.data()!);
    }
    // Strip anything an older, not-yet-moved account still has on its
    // public profile, so it can't leak through this model either.
    final data = Map<String, dynamic>.from(userDoc.data()!)
      ..remove('phoneNumber')
      ..remove('fcmTokens');
    return UserModel.fromMap(data, uid);
  }

  @override
  Future<String?> getContactPhone(String uid, {String? errandId}) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getContactPhone')
          .call<Map<String, dynamic>>({'uid': uid, 'errandId': ?errandId});
      return result.data['phoneNumber'] as String?;
    } on FirebaseFunctionsException catch (e) {
      // permission-denied is the EXPECTED answer when you aren't
      // allowed to see this number - just show no contact buttons.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  DocumentReference<Map<String, dynamic>> _privateRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('private').doc('account');

  /// Builds the signed-in user's model from their public profile plus
  /// their private account record (phone number, notification tokens).
  ///
  /// Also moves OLDER accounts over: if the phone number or tokens are
  /// still on the public profile, they're copied to the private record
  /// and removed from the public one. Runs once per account, on its next
  /// sign-in or app start.
  Future<UserModel> _withPrivate(String uid, Map<String, dynamic> publicData) async {
    final privateSnap = await _privateRef(uid).get();
    final privateData = privateSnap.data() ?? <String, dynamic>{};

    final legacyPhone = publicData['phoneNumber'] as String?;
    final legacyTokens = List<String>.from(publicData['fcmTokens'] ?? const []);
    if (legacyPhone != null || publicData.containsKey('fcmTokens')) {
      final phone = privateData['phoneNumber'] as String? ??
          _firebaseAuth.currentUser?.phoneNumber ??
          legacyPhone;
      final batch = _firestore.batch();
      batch.set(
        _privateRef(uid),
        {
          'phoneNumber': ?phone,
          'fcmTokens': FieldValue.arrayUnion(legacyTokens),
        },
        SetOptions(merge: true),
      );
      batch.update(_firestore.collection('users').doc(uid), {
        'phoneNumber': FieldValue.delete(),
        'fcmTokens': FieldValue.delete(),
      });
      await batch.commit();
      privateData['phoneNumber'] ??= phone;
      privateData['fcmTokens'] = {
        ...List<String>.from(privateData['fcmTokens'] ?? const []),
        ...legacyTokens,
      }.toList();
    }

    return UserModel.fromMap({
      ...publicData,
      'phoneNumber': privateData['phoneNumber'] ?? _firebaseAuth.currentUser?.phoneNumber ?? '',
      'fcmTokens': privateData['fcmTokens'] ?? const <String>[],
    }, uid);
  }

  @override
  Future<bool> hasRole(String role) async {
    final user = await getCurrentUser();
    if (user == null) return false;
    return user.roles.contains(role);
  }

  @override
  Future<void> addRole(String role) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    await _firestore.collection('users').doc(user.uid).update({
      'roles': FieldValue.arrayUnion([role]),
    });
  }

  @override
  Future<String> uploadAvatar(File image) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    try {
      final compressed = await ImageCompressionService.compressImage(image, quality: 80);
      // One fixed name per user, so a new photo replaces the old one
      // instead of piling up in Storage.
      final ref = FirebaseStorage.instance.ref('users/$uid/avatar/avatar.jpg');
      // Content type is required by storage.rules (images only).
      await ref.putFile(compressed, SettableMetadata(contentType: 'image/jpeg'));
      return ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }

  @override
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final updateData = <String, dynamic>{};

    // Field names must match UserModel.fromMap()'s keys exactly
    // (displayName/photoUrl, camelCase - UserModel's own convention,
    // consistent with fcmTokens/averageRating/etc. elsewhere on the
    // same model). This previously wrote display_name/photo_url
    // (snake_case) instead - the write always succeeded, but
    // UserModel never reads those keys, so an edited name silently
    // never showed up anywhere in the app at all.
    if (displayName != null) {
      updateData['displayName'] = displayName;
      await user.updateDisplayName(displayName);
    }

    if (photoUrl != null) {
      updateData['photoUrl'] = photoUrl;
      await user.updatePhotoURL(photoUrl);
    }

    if (updateData.isNotEmpty) {
      await _firestore.collection('users').doc(user.uid).update(updateData);
    }
  }

  ///Singleton factory
  static final FirebaseAuthRepository _instance =
      FirebaseAuthRepository._internal();

  factory FirebaseAuthRepository() {
    return _instance;
  }

  FirebaseAuthRepository._internal();
}