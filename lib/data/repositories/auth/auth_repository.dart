import 'dart:io';

// lib/domain/repositories/auth_repository.dart


import 'package:the_runner/data/models/user_model.dart';

abstract class AuthRepository {
  /// Sign in with phone number (OTP sent via SMS).
  /// Returns the Firebase verificationId once the SMS has actually been
  /// sent - NOT once verifyPhoneNumber's callbacks are merely registered.
  Future<String> signInWithPhone(String phoneNumber);

  /// Fires when Android verifies the number automatically (no code
  /// typed). The profile is already created or loaded.
  Stream<UserModel> get autoSignIns;

  /// Verify OTP code
  Future<UserModel> verifyOtp(String verificationId, String otpCode);

  /// Sign out current user
  Future<void> signOut();

  /// Permanently delete the signed-in user's account and their data
  /// (runs the deleteAccount Cloud Function), then sign out locally.
  Future<void> deleteAccount();

  /// Get currently authenticated user (stream for realtime changes)
  Stream<UserModel?> get currentUserStream;

  /// Get current user once
  Future<UserModel?> getCurrentUser();

  /// Get any user by uid (e.g. showing the runner who bid on an errand,
  /// or the requester who posted it). Unlike getCurrentUser(),
  /// this isn't restricted to the signed-in user.
  Future<UserModel?> getUserById(String uid);

  /// Another user's phone number, if you're allowed to see it (you're
  /// matched with them on [errandId]). Null when not allowed. Checked on
  /// the server by the getContactPhone function.
  Future<String?> getContactPhone(String uid, {String? errandId});

  /// Check if user has specific role
  Future<bool> hasRole(String role);

  /// Add role to user (e.g. 'runner' after runner onboarding)
  Future<void> addRole(String role);

  /// Upload a new profile photo for the signed-in user. Returns its URL
  /// (save it with [updateUserProfile]).
  Future<String> uploadAvatar(File image);

  /// Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
  });
}