import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once on app start to check whether a user session already exists.
class AuthenticationStarted extends AuthEvent {}

class SignInWithPhone extends AuthEvent {
  final String phoneNumber;

  const SignInWithPhone(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class VerifyOtp extends AuthEvent {
  final String verificationId;
  final String otpCode;

  const VerifyOtp({required this.verificationId, required this.otpCode});

  @override
  List<Object?> get props => [verificationId, otpCode];
}

class SignOut extends AuthEvent {}

class UpdateProfile extends AuthEvent {
  final String? displayName;
  final String? photoUrl;

  const UpdateProfile({this.displayName, this.photoUrl});

  @override
  List<Object?> get props => [displayName, photoUrl];
}

class AddRole extends AuthEvent {
  final String role;

  const AddRole(this.role);

  @override
  List<Object?> get props => [role];
}
