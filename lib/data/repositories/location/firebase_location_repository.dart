// lib/data/repositories/location_repository_impl.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:the_runner/data/services/location_service.dart';
import 'package:the_runner/data/repositories/location/location_repository.dart';

class FirebaseLocationRepository implements LocationRepository {
  final LocationService _locationService = LocationService();

  @override
  Stream<Position> get locationStream => _locationService.locationStream;

  @override
  Stream<LocationPermission> get permissionStream =>
      _locationService.permissionStream;

  @override
  Future<LocationPermission> checkAndRequestPermission() async {
    return await _locationService.checkAndRequestPermission();
  }

  @override
  Future<bool> isPermissionGranted() async {
    return await _locationService.isPermissionGranted();
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return await _locationService.isLocationServiceEnabled();
  }

  @override
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  @override
  Future<Position?> getCurrentPosition({
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    return await _locationService.getCurrentPosition(
      forceRefresh: forceRefresh,
      cacheDuration: cacheDuration,
    );
  }

  @override
  Future<Position?> getLastKnownPosition() async {
    return await _locationService.getLastKnownPosition();
  }

  @override
  Future<Position?> getSingleLocationUpdate({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return await _locationService.getSingleLocationUpdate(timeout: timeout);
  }

  @override
  void stopListening() {
    _locationService.stopListening();
  }

  @override
  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    return await _locationService.getAddressFromCoordinates(
      latitude: latitude,
      longitude: longitude,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<String> getCurrentAddress({bool forceRefresh = false}) async {
    return await _locationService.getCurrentAddress(forceRefresh: forceRefresh);
  }

  @override
  Future<String?> getCityFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    return await _locationService.getCityFromCoordinates(
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<String?> getCurrentCity() async {
    return await _locationService.getCurrentCity();
  }

  @override
  Future<Position?> getCoordinatesFromAddress(String address) async {
    return await _locationService.getCoordinatesFromAddress(address);
  }

  @override
  Future<List<Placemark>> searchPlaces(String query, {int limit = 10}) async {
    return await _locationService.searchPlaces(query, limit: limit);
  }

  @override
  double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return _locationService.calculateDistance(
      lat1: lat1,
      lng1: lng1,
      lat2: lat2,
      lng2: lng2,
    );
  }

  @override
  Future<double> distanceFromCurrent({
    required double targetLat,
    required double targetLng,
  }) async {
    return await _locationService.distanceFromCurrent(
      targetLat: targetLat,
      targetLng: targetLng,
    );
  }

  @override
  String formatDistance(double meters) {
    return _locationService.formatDistance(meters);
  }

  @override
  bool isWithinDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
    required double maxDistanceMeters,
  }) {
    return _locationService.isWithinDistance(
      lat1: lat1,
      lng1: lng1,
      lat2: lat2,
      lng2: lng2,
      maxDistanceMeters: maxDistanceMeters,
    );
  }

  @override
  (double minLat, double maxLat, double minLng, double maxLng) getBoundingBox({
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    return _locationService.getBoundingBox(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    );
  }

  @override
  Future<void> clearCache() async {
    await _locationService.clearCache();
  }

  @override
  void dispose() {
    _locationService.dispose();
  }

  ///Singleton factory
  static final FirebaseLocationRepository _instance =
      FirebaseLocationRepository._internal();

  factory FirebaseLocationRepository() {
    return _instance;
  }

  FirebaseLocationRepository._internal();
}
