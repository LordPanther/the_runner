// lib/domain/repositories/location_repository.dart
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

abstract class LocationRepository {
  /// Request location permissions
  Stream<Position> get locationStream;
  Stream<LocationPermission> get permissionStream;
  
  // Permissions
  Future<LocationPermission> checkAndRequestPermission();
  Future<bool> isPermissionGranted();
  Future<bool> isLocationServiceEnabled();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
  
  // Location retrieval
  Future<Position?> getCurrentPosition({bool forceRefresh, Duration? cacheDuration});
  Future<Position?> getLastKnownPosition();
  Future<Position?> getSingleLocationUpdate({Duration timeout});
  
  // Listening
  void stopListening();
  
  // Geocoding
  Future<String> getAddressFromCoordinates({required double latitude, required double longitude, bool forceRefresh});
  Future<String> getCurrentAddress({bool forceRefresh});
  Future<String?> getCityFromCoordinates({required double latitude, required double longitude});
  Future<String?> getCurrentCity();
  Future<Position?> getCoordinatesFromAddress(String address);
  Future<List<Placemark>> searchPlaces(String query, {int limit});
  
  // Distance
  double calculateDistance({required double lat1, required double lng1, required double lat2, required double lng2});
  Future<double> distanceFromCurrent({required double targetLat, required double targetLng});
  String formatDistance(double meters);
  bool isWithinDistance({required double lat1, required double lng1, required double lat2, required double lng2, required double maxDistanceMeters});
  
  // Utilities
  (double minLat, double maxLat, double minLng, double maxLng) getBoundingBox({required double lat, required double lng, required double radiusKm});
  Future<void> clearCache();
  void dispose();
}