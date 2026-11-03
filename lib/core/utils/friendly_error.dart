// lib/core/utils/friendly_error.dart

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:the_runner/utils/translate.dart';

/// Turns any error (an exception, or the message string a bloc stored
/// from one) into a TRANSLATION KEY for a short, plain message people
/// can act on. Raw errors like "[cloud_firestore/permission-denied] The
/// caller does not have permission..." are never shown on screen.
///
/// Blocs usually store `e.toString()`, which still contains the Firebase
/// code (e.g. "cloud_firestore/unavailable"), so matching on the text
/// works for both exceptions and stored messages.
String friendlyErrorKey(Object? error) {
  if (error == null) return 'error_generic';
  if (error is SocketException || error is TimeoutException) {
    return 'error_network';
  }

  final text = (error is FirebaseException
          ? '${error.plugin}/${error.code} ${error.message ?? ''}'
          : error.toString())
      .toLowerCase();

  bool has(List<String> parts) => parts.any(text.contains);

  // The Runner's own rules, thrown by the repositories and Cloud
  // Functions in plain English (e.g. "You already placed a bid on this
  // errand").
  if (has(['already placed a bid'])) return 'error_already_bid';
  if (has(['no longer open'])) return 'error_errand_not_open';
  if (has(['between the starting fee and the cap'])) return 'error_bid_out_of_range';
  if (has(['cap must be at least'])) return 'error_cap_below_start';
  if (has(['more than the purchase budget'])) return 'error_over_budget';
  if (has(['payment link unavailable'])) return 'error_payment_link';
  if (has(['invalid image format', 'invalid document format'])) {
    return 'error_file_type';
  }
  if (has([
    'errand has changed',
    'only the requester',
    'only the runner',
    'not funded yet',
  ])) {
    return 'error_errand_changed';
  }
  if (has(['no authenticated user', 'not authenticated', 'must be logged in'])) {
    return 'error_signed_out';
  }

  // Phone sign-in
  if (has(['invalid-verification-code'])) return 'error_wrong_code';
  if (has(['session-expired', 'code-expired', 'invalid-verification-id'])) {
    return 'error_code_expired';
  }
  if (has(['invalid-phone-number'])) return 'enter_a_valid_phone_number';

  // Connection
  if (has([
    'network-request-failed',
    '/unavailable',
    'deadline-exceeded',
    'socketexception',
    'failed host lookup',
    'timeoutexception',
    'connection reset',
    'network is unreachable',
    'retry-limit-exceeded',
  ])) {
    return 'error_network';
  }

  // Too many attempts
  if (has(['too-many-requests', 'quota-exceeded', 'resource-exhausted'])) {
    return 'error_too_many';
  }

  // Not allowed (rules said no, or the session ran out)
  if (has([
    'permission-denied',
    'unauthenticated',
    'storage/unauthorized',
    'storage/unauthenticated',
    'requires-recent-login',
    'user-token-expired',
  ])) {
    return 'error_permission';
  }

  // Gone
  if (has(['not-found', 'object-not-found', 'not found'])) {
    return 'error_not_found';
  }

  // Upload too big
  if (has(['payload', 'too large', 'file-too-large'])) {
    return 'error_upload_rejected';
  }

  if (has(['canceled', 'cancelled'])) return 'error_cancelled';

  return 'error_generic';
}

/// Shorthand for screens: context.errorText(e) or
/// context.errorText(state.message).
///
/// [action] is an optional translation key saying WHAT failed, put in
/// front of the reason: errorText(e, action: 'cancel_errand_failed') ->
/// "Couldn't cancel the errand. No internet connection. Check...".
///
/// If the message is itself a translation key (blocs emit keys for
/// their own messages, e.g. 'search_no_location'), that's used as is.
/// The raw error is logged for debugging, never shown.
extension FriendlyErrorContext on BuildContext {
  String errorText(Object? error, {String? action}) {
    final t = Translate.of(this);
    final String reason;
    if (error is String && t.has(error)) {
      reason = t.translate(error);
    } else {
      debugPrint('Error shown to user: $error');
      reason = t.translate(friendlyErrorKey(error));
    }
    return action == null ? reason : '${t.translate(action)} $reason';
  }
}
