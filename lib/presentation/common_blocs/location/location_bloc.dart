// Example: Location Bloc
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:geolocator/geolocator.dart';
import 'package:the_runner/data/repositories/location/firebase_location_repository.dart';
import 'package:the_runner/data/repositories/location/location_repository.dart';
import 'package:the_runner/data/services/demo_account.dart';
import 'package:the_runner/presentation/common_blocs/location/location_event.dart';
import 'package:the_runner/presentation/common_blocs/location/location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository _locationRepository = FirebaseLocationRepository();
  Stream<Position>? _locationStream;

  LocationBloc() : super(LocationInitial()) {
    on<CheckPermission>((event, emit) async {
      await _onCheckPermission(event, emit);
    });
    on<RequestPermission>((event, emit) async {
      await _onRequestPermission(event, emit);
    });
    on<GetCurrentLocation>((event, emit) async {
      await _onGetCurrentLocation(event, emit);
    });
    on<GetCurrentAddress>((event, emit) async {
      await _onGetCurrentAddress(event, emit);
    });
    on<SearchPlaces>((event, emit) async {
      await _onSearchPlaces(event, emit);
    });
    on<SubscribeToLocationUpdates>(
      _onSubscribeToLocationUpdates,
      transformer: restartable(),
    );
    on<UnsubscribeFromLocationUpdates>((event, emit) {
      _onUnsubscribeFromLocationUpdates(event, emit);
    });
  }

  Future<void> _onCheckPermission(
    CheckPermission event,
    Emitter<LocationState> emit,
  ) async {
    // Play reviewer accounts have a fixed location: no GPS or permission.
    if (DemoAccount.instance.isActive) {
      emit(PermissionGranted());
      return;
    }

    final isEnabled = await _locationRepository.isLocationServiceEnabled();
    if (!isEnabled) {
      emit(const LocationError(message: 'location_services_off'));
      return;
    }
    
    final permission = await _locationRepository.isPermissionGranted();
    if (permission) {
      emit(PermissionGranted());
    } else {
      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.deniedForever) {
        emit(PermissionDeniedForever());
      } else {
        emit(PermissionDenied());
      }
    }
  }

  Future<void> _onRequestPermission(
    RequestPermission event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());

    if (DemoAccount.instance.isActive) {
      emit(PermissionGranted());
      add(GetCurrentLocation(true));
      return;
    }

    final permission = await _locationRepository.checkAndRequestPermission();
    
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      emit(PermissionGranted());
      add(GetCurrentLocation(true));
    } else if (permission == LocationPermission.deniedForever) {
      emit(PermissionDeniedForever());
    } else {
      emit(PermissionDenied());
    }
  }

  Future<void> _onGetCurrentLocation(
    GetCurrentLocation event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());
    
    final position = await _locationRepository.getCurrentPosition(
      forceRefresh: event.forceRefresh,
    );
    
    if (position != null) {
      final address = await _locationRepository.getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      emit(LocationLoaded(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      ));
    } else {
      emit(const LocationError(message: 'location_failed'));
    }
  }

  Future<void> _onGetCurrentAddress(
    GetCurrentAddress event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());
    
    final address = await _locationRepository.getCurrentAddress();
    
    emit(AddressLoaded(address: address));
  }

  Future<void> _onSearchPlaces(
    SearchPlaces event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());
    
    final places = await _locationRepository.searchPlaces(event.query);
    
    emit(PlacesSearchResults(places: places as List<String>));
  }

  Future<void> _onSubscribeToLocationUpdates(
    SubscribeToLocationUpdates event,
    Emitter<LocationState> emit,
  ) async {
    _locationStream = _locationRepository.locationStream;
    
    await emit.onEach(
      _locationStream!,
      onData: (_) {
        if (!isClosed) add(GetCurrentLocation(true));
      },
    );
  }

  void _onUnsubscribeFromLocationUpdates(
    UnsubscribeFromLocationUpdates event,
    Emitter<LocationState> emit,
  ) {
    _locationRepository.stopListening();
  }

  @override
  Future<void> close() {
    _locationRepository.dispose();
    return super.close();
  }
}
