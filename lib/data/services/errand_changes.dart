// lib/data/services/errand_changes.dart

import 'package:flutter/foundation.dart';

/// A nudge that "something about my errands changed", so lists that stay
/// mounted (the My Errands tab lives in an IndexedStack and never
/// rebuilds on its own) know to reload.
///
/// Fired by ErrandBloc after any action succeeds (post, bid, accept,
/// pay, proof, approve, dispute, cancel) and by the bottom nav when the
/// My Errands tab is opened, which also catches changes the OTHER
/// person made in the meantime.
class ErrandChanges {
  static final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  static Listenable get listenable => _tick;

  static void notify() => _tick.value++;

  ErrandChanges._();
}
