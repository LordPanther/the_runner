import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:the_runner/data/local/pref.dart';
import 'package:the_runner/data/services/demo_account.dart';

/// Comprehensive location service with caching, permission handling,
/// and real-time location updates
class LocationService {
  // Cache keys
  static const String _cachedLatKey = 'cached_latitude';
  static const String _cachedLngKey = 'cached_longitude';
  static const String _cachedAddressKey = 'cached_address';
  static const String _cachedTimestampKey = 'cached_location_timestamp';
  static const String _lastKnownCityKey = 'last_known_city';
  static const String _lastKnownAreaKey = 'last_known_area';

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Location settings.
  // NOTE: accuracy is `.medium` rather than `.high`, and timeLimit is 20s
  // rather than the original 5s. `.high` forces a GPS-only fix, which can
  // easily take 10-30+ seconds on a cold start or indoors - 5 seconds was
  // never realistically enough and meant getCurrentPosition() basically
  // always failed on first use. `.medium` allows network/wifi-assisted
  // positioning too, which resolves much faster and is more than accurate
  // enough for "find businesses within a few km" - this app never needed
  // GPS-grade precision.
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 10, // Update every 10 meters
    timeLimit: Duration(seconds: 20),
  );

  /// Settings that bypass Google Play Services' fused provider and talk to
  /// Android's own LocationManager instead.
  ///
  /// Some devices ship with a Play Services install that's broken or
  /// uncertified (seen on a Hisense Enigma SE: DEVELOPER_ERROR and
  /// "Unknown calling package name" from GMS). There the fused provider
  /// accepts the request and then simply never delivers a position, so the
  /// app waits out its timeout and reports no location - even with
  /// permission granted and location switched on. LocationManager has no
  /// dependency on Play Services, so it works on those devices.
  ///
  /// Accuracy is `low` on purpose: this app only needs town-level
  /// positioning, and a coarse request lets Android pick the network
  /// provider instead of insisting on a GPS fix (slow or impossible
  /// indoors).
  static LocationSettings _locationManagerSettings() {
    const timeLimit = Duration(seconds: 20);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 10,
        forceLocationManager: true,
        timeLimit: timeLimit,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.low,
      distanceFilter: 10,
      timeLimit: timeLimit,
    );
  }

  // Stream controllers
  final _locationStreamController = StreamController<Position>.broadcast();
  final _permissionStreamController =
      StreamController<LocationPermission>.broadcast();

  // Current state
  Position? _currentPosition;
  LocationPermission _currentPermission = LocationPermission.denied;
  bool _isListening = false;
  StreamSubscription<Position>? _positionSub;

  // ============================================================
  // STREAMS
  // ============================================================

  /// Stream of location updates
  Stream<Position> get locationStream => _locationStreamController.stream;

  /// Stream of permission changes
  Stream<LocationPermission> get permissionStream =>
      _permissionStreamController.stream;

  // ============================================================
  // PERMISSION HANDLING
  // ============================================================

  /// Check and request location permissions
  Future<LocationPermission> checkAndRequestPermission() async {
    try {
      // Check if location services are enabled
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        _currentPermission = LocationPermission.denied;
        _permissionStreamController.add(_currentPermission);
        return LocationPermission.denied;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _currentPermission = LocationPermission.deniedForever;
        _permissionStreamController.add(_currentPermission);
        return LocationPermission.deniedForever;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _currentPermission = permission;
        _permissionStreamController.add(_currentPermission);

        // Start listening if not already
        if (!_isListening) {
          _startListening();
        }

        return permission;
      }

      _currentPermission = LocationPermission.denied;
      _permissionStreamController.add(_currentPermission);
      return LocationPermission.denied;
    } catch (e) {
      debugPrint('Failed to check/request permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Check if permission is granted
  Future<bool> isPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open app settings (for when permission is denied forever)
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  // ============================================================
  // LOCATION RETRIEVAL
  // ============================================================

  /// Get current location (with caching)
  Future<Position?> getCurrentPosition({
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    // Play reviewer accounts use a fixed South African location.
    final demo = DemoAccount.instance.position;
    if (demo != null) return demo;

    try {
      // Check permission first
      final hasPermission = await isPermissionGranted();
      if (!hasPermission) {
        debugPrint('Location permission not granted');
        return null;
      }

      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        debugPrint('Location services not enabled');
        return null;
      }

      // Check cache if not forcing refresh
      if (!forceRefresh) {
        final cachedPosition = _getCachedPosition(
          cacheDuration ?? _cacheDuration,
        );
        if (cachedPosition != null) {
          debugPrint('Returning cached location');
          return cachedPosition;
        }
      }

      // Get fresh location
      debugPrint('Fetching fresh location');
      final position = await _fetchFreshPosition();

      // Cache the result
      _cachePosition(position);
      _currentPosition = position;

      return position;
    } catch (e) {
      debugPrint('Failed to get current position: $e');

      // NOTE: fallback chain, in order of freshness:
      // 1. OS-level last known fix (Geolocator.getLastKnownPosition) - this
      //    can be populated by ANY app on the device (Maps, camera geotag,
      //    etc.), so it's often available even when THIS app has never
      //    successfully gotten a fix of its own yet (e.g. very first run).
      // 2. This app's own cached position, even if stale.
      // Without step 1, a first-ever run with a slow/failed GPS fix had
      // nothing to fall back to at all and just returned null.
      // Tried twice: once through the default provider, once straight
      // through Android's LocationManager (which still works when Play
      // Services doesn't, and often holds a fix another app already got).
      for (final viaLocationManager in const [false, true]) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition(
            forceAndroidLocationManager: viaLocationManager,
          );
          if (lastKnown != null && _isRecentEnough(lastKnown)) {
            debugPrint(
              'Falling back to OS last known position'
              '${viaLocationManager ? ' (via LocationManager)' : ''}',
            );
            _cachePosition(lastKnown);
            return lastKnown;
          }
        } catch (_) {
          // Ignore - try the next source.
        }
      }

      return _getCachedPosition(Duration(days: 1));
    }
  }

  /// Asks for a fresh fix from BOTH the default provider (Google Play
  /// Services' fused provider) and Android's own LocationManager at the
  /// same time, and returns whichever produces a position first.
  ///
  /// Racing them, rather than trying one then the other, means a healthy
  /// phone pays no extra wait, while a phone with broken Play Services
  /// still gets an answer from LocationManager instead of timing out.
  /// Only fails if every provider fails. Non-Android platforms have just
  /// the one provider.
  Future<Position> _fetchFreshPosition() {
    final completer = Completer<Position>();
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    var pending = isAndroid ? 2 : 1;
    Object? lastError;

    void settle(String source, Position? position, Object? error) {
      if (completer.isCompleted) return;
      if (position != null) {
        // Accuracy radius in metres - the one number that tells us
        // whether a "wrong location" is a bad fix (e.g. +-3000m from
        // cell towers or Approximate mode) or something else entirely.
        debugPrint(
          'Location fix via $source (+-${position.accuracy.round()}m)',
        );
        completer.complete(position);
        return;
      }
      debugPrint('Location provider failed ($source): $error');
      lastError = error ?? lastError;
      pending--;
      if (pending == 0) {
        completer.completeError(
          lastError ?? TimeoutException('No location provider returned a fix'),
        );
      }
    }

    Geolocator.getCurrentPosition(locationSettings: _locationSettings).then(
      (position) => settle('Google Play Services', position, null),
      onError: (Object error) => settle('Google Play Services', null, error),
    );

    if (isAndroid) {
      Geolocator.getCurrentPosition(
        locationSettings: _locationManagerSettings(),
      ).then(
        (position) => settle('Android LocationManager', position, null),
        onError: (Object error) =>
            settle('Android LocationManager', null, error),
      );
    }

    return completer.future;
  }

  /// Get last known location (from cache or device)
  Future<Position?> getLastKnownPosition() async {
    final demo = DemoAccount.instance.position;
    if (demo != null) return demo;
    try {
      // Check device's last known position
      final devicePosition = await Geolocator.getLastKnownPosition();
      if (devicePosition != null && _isRecentEnough(devicePosition)) {
        _cachePosition(devicePosition);
        return devicePosition;
      }

      // Fallback to cached
      return _getCachedPosition(Duration(days: 7));
    } catch (e) {
      debugPrint('Failed to get last known position: $e');
      return _getCachedPosition(Duration(days: 7));
    }
  }

  /// Get single location update (waits for a fresh fix)
  Future<Position?> getSingleLocationUpdate({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final demo = DemoAccount.instance.position;
    if (demo != null) return demo;

    try {
      final hasPermission = await isPermissionGranted();
      if (!hasPermission) return null;

      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(timeout);

      _cachePosition(position);
      _currentPosition = position;

      return position;
    } catch (e) {
      debugPrint('Failed to get single location update: $e');
      return null;
    }
  }

  // ============================================================
  // LOCATION LISTENING
  // ============================================================

  /// Settings for the continuous stream. Same as the one-shot settings
  /// but with NO timeLimit: on a stream, timeLimit means "error if no
  /// update arrives within 20s", and with a 10m distance filter a phone
  /// lying still never sends one. That made the stream time out, error,
  /// retry and time out again every session, and the plugin then threw
  /// "No active stream to cancel" (the red error in the debug console).
  static LocationSettings _streamSettings({required bool useLocationManager}) {
    if (useLocationManager && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 10,
        forceLocationManager: true,
      );
    }
    return LocationSettings(
      accuracy: useLocationManager ? LocationAccuracy.low : LocationAccuracy.medium,
      distanceFilter: 10,
    );
  }

  /// Start listening to location updates
  void _startListening({bool useLocationManager = false}) {
    if (_isListening) return;

    _isListening = true;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _streamSettings(useLocationManager: useLocationManager),
    ).listen(
      (Position position) {
        _currentPosition = position;
        _cachePosition(position);
        if (!_locationStreamController.isClosed) {
          _locationStreamController.add(position);
        }
      },
      onError: (Object error) {
        debugPrint('Location stream error: $error');
        _positionSub?.cancel();
        _positionSub = null;
        _isListening = false;

        // The default provider failed - retry once through Android's
        // LocationManager (see _locationManagerSettings for why). Only
        // once, so a genuine no-signal situation can't loop forever.
        if (!useLocationManager &&
            defaultTargetPlatform == TargetPlatform.android) {
          debugPrint('Retrying location stream via Android LocationManager');
          _startListening(useLocationManager: true);
        }
      },
      cancelOnError: false,
    );
  }

  /// Stop listening to location updates
  void stopListening() {
    _positionSub?.cancel();
    _positionSub = null;
    _isListening = false;
  }

  // ============================================================
  // CACHING
  // ============================================================

  /// Cache position to SharedPreferences
  /// The OS "last known" position has no age limit of its own - it can
  /// be from hours or days ago, wherever the phone last got a fix
  /// (another town, a trip). Beyond this age it's more misleading than
  /// useful for a "what's near me" app, so it's ignored.
  static const Duration _maxLastKnownAge = Duration(hours: 2);

  bool _isRecentEnough(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return age <= _maxLastKnownAge;
  }

  void _cachePosition(Position position) {
    try {
      LocalPref.setDouble(_cachedLatKey, position.latitude);
      LocalPref.setDouble(_cachedLngKey, position.longitude);
      LocalPref.setString(_cachedAddressKey, '');
      // The fix's REAL timestamp, not DateTime.now(). Stamping "now"
      // made an hours-old OS last-known position (possibly from another
      // town) look brand new, so it was then served as "fresh" for the
      // whole cache window - the cause of the app sometimes showing a
      // place you weren't at.
      LocalPref.setInt(
        _cachedTimestampKey,
        position.timestamp.millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Failed to cache position: $e');
    }
  }

  /// Get cached position if not expired
  Position? _getCachedPosition(Duration maxAge) {
    final cachedLat = LocalPref.getDouble(_cachedLatKey);
    final cachedLng = LocalPref.getDouble(_cachedLngKey);
    final cachedTimestamp = LocalPref.getInt(_cachedTimestampKey);

    if (cachedLat == null || cachedLng == null || cachedTimestamp == null) {
      return null;
    }

    final cacheAge = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(cachedTimestamp),
    );

    if (cacheAge > maxAge) {
      return null;
    }

    return Position(
      longitude: cachedLng,
      latitude: cachedLat,
      timestamp: DateTime.fromMillisecondsSinceEpoch(cachedTimestamp),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  /// Clear cached location
  Future<void> clearCache() async {
    await LocalPref.remove(_cachedLatKey);
    await LocalPref.remove(_cachedLngKey);
    await LocalPref.remove(_cachedAddressKey);
    await LocalPref.remove(_cachedTimestampKey);
    await LocalPref.remove(_lastKnownCityKey);
    await LocalPref.remove(_lastKnownAreaKey);
  }

  // ============================================================
  // GEOCODING (Reverse)
  // ============================================================

  /// Get address from coordinates (with caching)
  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache
      if (!forceRefresh) {
        final cachedAddress = _getCachedAddress(latitude, longitude);
        if (cachedAddress != null) {
          return cachedAddress;
        }
      }

      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return '$latitude, $longitude';
      }

      final placemark = placemarks.first;
      final addressParts = [
        placemark.street,
        placemark.locality,
        placemark.administrativeArea,
        placemark.postalCode,
        placemark.country,
      ].where((part) => part != null && part.isNotEmpty);

      final address = addressParts.join(', ');

      // Cache the address
      _cacheAddress(latitude, longitude, address);

      // Cache city and area for quick access
      if (placemark.locality != null) {
        await LocalPref.setString(_lastKnownCityKey, placemark.locality!);
      }
      if (placemark.subAdministrativeArea != null) {
        await LocalPref.setString(
          _lastKnownAreaKey,
          placemark.subAdministrativeArea!,
        );
      }

      return address;
    } catch (e) {
      debugPrint('Failed to get address from coordinates: $e');
      return '$latitude, $longitude';
    }
  }

  /// Get current address
  Future<String> getCurrentAddress({bool forceRefresh = false}) async {
    final position = await getCurrentPosition(forceRefresh: forceRefresh);
    if (position == null) {
      return 'Unknown location';
    }

    return await getAddressFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
      forceRefresh: forceRefresh,
    );
  }

  /// Get city from coordinates
  Future<String?> getCityFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      return placemarks.first.locality;
    } catch (e) {
      debugPrint('Failed to get city: $e');
      return null;
    }
  }

  /// Get current city
  Future<String?> getCurrentCity() async {
    // Check cached city first
    final cachedCity = LocalPref.getString(_lastKnownCityKey);
    if (cachedCity != null) {
      return cachedCity;
    }

    final position = await getCurrentPosition();
    if (position == null) return null;

    return await getCityFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  // ============================================================
  // GEOCODING (Forward)
  // ============================================================

  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) return null;

      final loc = locations.first;

      // Manually create a Position object using the Location's coordinates
      return Position(
        latitude: loc.latitude,
        longitude: loc.longitude,
        timestamp: loc.timestamp, // or DateTime.now()
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    } catch (e) {
      debugPrint('Failed to get coordinates from address: $e');
      return null;
    }
  }

  /// Search for places by query
  Future<List<Placemark>> searchPlaces(String query, {int limit = 10}) async {
    try {
      final locations = await locationFromAddress(query);
      final List<Placemark> results = [];

      for (int i = 0; i < locations.length && i < limit; i++) {
        final location = locations[i];
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (placemarks.isNotEmpty) {
          results.add(placemarks.first);
        }
      }

      return results;
    } catch (e) {
      debugPrint('Failed to search places: $e');
      return [];
    }
  }

  // ============================================================
  // DISTANCE CALCULATIONS
  // ============================================================

  /// Calculate distance between two coordinates in meters
  double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Calculate distance from current location to target
  Future<double> distanceFromCurrent({
    required double targetLat,
    required double targetLng,
  }) async {
    final current = await getCurrentPosition();
    if (current == null) return double.infinity;

    return Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      targetLat,
      targetLng,
    );
  }

  /// Get distance in human-readable format
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      final km = meters / 1000;
      if (km < 10) {
        return '${km.toStringAsFixed(1)}km';
      } else {
        return '${km.round()}km';
      }
    }
  }

  // ============================================================
  // PRIVATE CACHING METHODS
  // ============================================================

  void _cacheAddress(double lat, double lng, String address) {
    try {
      final key = 'address_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
      LocalPref.setString(key, address);
      LocalPref.setString(_cachedAddressKey, address);

      // Clean up old address caches
      _cleanOldAddressCaches();
    } catch (e) {
      debugPrint('Failed to cache address: $e');
    }
  }

  String? _getCachedAddress(double lat, double lng) {
    try {
      final key = 'address_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
      return LocalPref.getString(key);
    } catch (e) {
      return null;
    }
  }

  void _cleanOldAddressCaches() async {
    // Keep only last 20 address caches
    try {
      final keys = LocalPref.getKeys();
      final addressKeys = keys.where((k) => k.startsWith('address_')).toList();

      if (addressKeys.length > 20) {
        final toRemove = addressKeys.sublist(20);
        for (final key in toRemove) {
          await LocalPref.remove(key);
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Check if two coordinates are within a certain distance
  bool isWithinDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
    required double maxDistanceMeters,
  }) {
    final distance = calculateDistance(
      lat1: lat1,
      lng1: lng1,
      lat2: lat2,
      lng2: lng2,
    );
    return distance <= maxDistanceMeters;
  }

  /// Get bounding box around a location
  (double minLat, double maxLat, double minLng, double maxLng) getBoundingBox({
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    final double latDelta = radiusKm / 111.0;
    final double lngDelta =
        radiusKm / (111.0 * _cos(lat * 3.141592653589793 / 180));

    return (lat - latDelta, lat + latDelta, lng - lngDelta, lng + lngDelta);
  }

  double _cos(double x) => cos(x);

  /// Dispose resources
  void dispose() {
    stopListening();
    _locationStreamController.close();
    _permissionStreamController.close();
  }
}
