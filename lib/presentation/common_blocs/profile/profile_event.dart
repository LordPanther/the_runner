import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the currently authenticated user's profile.
/// Fired by AppView once AuthBloc reaches Authenticated.
class LoadProfile extends ProfileEvent {}

class UpdateProfileDetails extends ProfileEvent {
  final String? displayName;
  final String? photoUrl;

  const UpdateProfileDetails({this.displayName, this.photoUrl});

  @override
  List<Object?> get props => [displayName, photoUrl];
}
