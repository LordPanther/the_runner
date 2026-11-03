// lib/core/widgets/loading_overlay.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:the_runner/app_view.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';

/// Shows a full-screen, blurred, input-blocking overlay while an async
/// operation (anything needing a network round-trip) is in flight.
///
/// This exists because a plain disabled-button flag only prevents a
/// SECOND tap on that ONE button - it does nothing to stop someone
/// tapping a different button, navigating back, or tapping the same
/// button again during the split second before setState() actually
/// disables it. A real report: tapping "Post Job" 5 times with no
/// visible feedback produced 6 duplicate jobs. AbsorbPointer at the
/// root Overlay blocks EVERY tap anywhere on screen, not just the one
/// button a developer remembered to guard.
///
/// Uses AppView.navigatorKey (already exists for push-notification
/// deep-linking) to reach the root Overlay, so this can be called from
/// anywhere - a bloc listener, a button handler - without needing a
/// BuildContext that's guaranteed to still be mounted.
class LoadingOverlay {
  static OverlayEntry? _entry;
  static int _showToken = 0;

  /// Safe to call even if already showing - does nothing rather than
  /// stacking a second overlay, since a single in-flight operation is
  /// all this is meant to represent at once.
  static void show({
    String? message,
    Duration safetyTimeout = const Duration(seconds: 30),
  }) {
    if (_entry != null) return;

    final overlayState = AppView.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _entry = OverlayEntry(
      builder: (context) => _LoadingOverlayContent(message: message),
    );
    overlayState.insert(_entry!);

    // Safety net, not the primary mechanism - every real call site
    // should call hide() itself on every exit path. This exists so a
    // future screen that forgets to (the exact mistake that caused the
    // 6-duplicate-jobs bug in the first place) leaves the app merely
    // slow for 30 seconds, not stuck forever.
    final token = ++_showToken;
    Future.delayed(safetyTimeout, () {
      if (_showToken == token) hide();
    });
  }

  static void hide() {
    _showToken++;
    _entry?.remove();
    _entry = null;
  }

  /// Wraps a single async call: shows the overlay, runs [action], hides
  /// the overlay afterward regardless of success or failure. The
  /// common case - most call sites want exactly this, not separate
  /// show()/hide() calls around their own try/catch.
  static Future<T> wrap<T>(
    Future<T> Function() action, {
    String? message,
  }) async {
    show(message: message);
    try {
      return await action();
    } finally {
      hide();
    }
  }
}

class _LoadingOverlayContent extends StatelessWidget {
  final String? message;

  const _LoadingOverlayContent({this.message});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        // The actual fix: swallows every tap/gesture underneath,
        // anywhere on screen, not just on whichever button triggered
        // this - unlike a per-button disabled flag, this can't be
        // bypassed by tapping something else instead.
        absorbing: true,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            color: Colors.black.withValues(alpha: 0.25),
            child: Center(
              child: Material(
                // Without this, Text below renders with no Material
                // ancestor to inherit proper styling from - shows up as
                // an unstyled default, including a visible underline.
                // Transparency type keeps this purely a text-styling
                // fix with no visual background/elevation of its own.
                type: MaterialType.transparency,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: ColorConst.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: ColorConst.primaryColor),
                      if (message != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          message!,
                          style: FontConst.MEDIUM_DEFAULT_16,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
