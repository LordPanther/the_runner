import 'package:equatable/equatable.dart';

abstract class LocationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckPermission extends LocationEvent {}

class RequestPermission extends LocationEvent {}

class GetCurrentLocation extends LocationEvent {
  final bool forceRefresh;

  GetCurrentLocation(this.forceRefresh);

  @override
  List<Object?> get props => [forceRefresh];
}

class GetCurrentAddress extends LocationEvent {}

class SearchPlaces extends LocationEvent {
  final String query;

  SearchPlaces(this.query);

  @override
  List<Object?> get props => [query];
}

class SubscribeToLocationUpdates extends LocationEvent {}

class UnsubscribeFromLocationUpdates extends LocationEvent {}
