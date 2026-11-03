// lib/data/local/search_radius_preference.dart
 
import 'package:the_runner/data/local/pref.dart';
 
/// Single source of truth for the user's preferred search radius -
/// read directly by the errand feed (and anything else that searches
/// nearby) rather than threading it through bloc constructors. LocalPref's getters are synchronous, so
/// this can be read anywhere without async ceremony.
class SearchRadiusPreference {
  static const String _key = 'searchRadiusKm';
  static const double defaultRadiusKm = 10.0;
 
  static double get() => LocalPref.getDouble(_key) ?? defaultRadiusKm;
 
  static void set(double radiusKm) => LocalPref.setDouble(_key, radiusKm);
}