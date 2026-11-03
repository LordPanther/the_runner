import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/data/repositories/repository.dart';
import 'package:the_runner/presentation/common_blocs/profile/profile_event.dart';
import 'package:the_runner/presentation/common_blocs/profile/profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final AuthRepository _authRepository = AppRepository.authRepository;

  ProfileBloc() : super(ProfileInitial()) {
    on<LoadProfile>((event, emit) async {
      await _onLoadProfile(event, emit);
    });
    on<UpdateProfileDetails>((event, emit) async {
      await _onUpdateProfileDetails(event, emit);
    });
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user == null) {
        emit(const ProfileError(message: 'error_signed_out'));
        return;
      }
      emit(ProfileLoaded(user: user));
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }

  Future<void> _onUpdateProfileDetails(
    UpdateProfileDetails event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      await _authRepository.updateUserProfile(
        displayName: event.displayName,
        photoUrl: event.photoUrl,
      );

      final user = await _authRepository.getCurrentUser();
      if (user == null) {
        emit(const ProfileError(message: 'error_signed_out'));
        return;
      }
      emit(ProfileUpdateSuccess(user: user));
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }
}
