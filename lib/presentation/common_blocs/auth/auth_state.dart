import 'package:equatable/equatable.dart';
import 'package:the_runner/data/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Before AuthenticationStarted has been processed at all.
class Uninitialized extends AuthState {}

class AuthLoading extends AuthState {}

class Unauthenticated extends AuthState {}

class Authenticated extends AuthState {
  final UserModel user;

  const Authenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class PhoneVerificationSent extends AuthState {
  final String verificationId;

  const PhoneVerificationSent({required this.verificationId});

  @override
  List<Object?> get props => [verificationId];
}

class ProfileUpdated extends AuthState {
  final UserModel user;

  const ProfileUpdated({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
