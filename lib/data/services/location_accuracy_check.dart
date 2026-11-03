import 'package:geolocator/geolocator.dart';

/// Detects Android's "Approximate location" permission mode (Android 12+).
///
/// When a user - or a Family Link parent - grants location as Approximate
/// instead of Precise, Android deliberately fuzzes every coordinate the
/// app receives by up to roughly 3km, snapped to a grid. Nothing in the
/// app looks broken: fixes arrive quickly and look plausible, they're
/// just consistently "somewhere nearby but not here". That matches the
/// "wrong location, but not too far" reports, and no code change can
/// undo it - only the user switching Precise location on can.
class LocationAccuracyCheck {
  static Future<bool> isApproximateOnly() async {
    try {
      final status = await Geolocator.getLocationAccuracy();
      return status == LocationAccuracyStatus.reduced;
    } catch (_) {
      // Unsupported platform/OS version - assume precise rather than
      // nagging about a problem we can't confirm.
      return false;
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();
}
