import 'package:equatable/equatable.dart';

abstract class LocationState extends  Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class PermissionDenied extends LocationState {}

class PermissionDeniedForever extends LocationState {}

class PermissionGranted extends LocationState {}

class LocationLoaded extends LocationState {
  final double latitude;
  final double longitude;
  final String? address;

  const LocationLoaded({required this.latitude, required this.longitude, this.address});

  @override
  List<Object?> get props => [latitude, longitude, address];
}

class AddressLoaded extends LocationState {
  final String address;

  const AddressLoaded({required this.address});

  @override
  List<Object?> get props => [address];
}

class PlacesSearchResults extends LocationState {
  final List<String> places;

  const PlacesSearchResults({required this.places});

  @override
  List<Object?> get props => [places];
}

class LocationUpdating extends LocationState {
  final double latitude;
  final double longitude;

  const LocationUpdating({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}

class LocationError extends LocationState {
  final String message;

  const LocationError({required this.message});

  @override
  List<Object?> get props => [message];
}