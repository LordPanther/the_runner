import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/data/models/user_model.dart';
import 'package:the_runner/data/repositories/repository.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth_event.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth_state.dart';
import 'package:the_runner/data/services/block_list.dart';
import 'package:the_runner/data/services/demo_account.dart';
import 'package:the_runner/data/services/language_sync.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository = AppRepository.authRepository;
  String? _verificationId;
  StreamSubscription<UserModel>? _autoSignInSub;

  AuthBloc() : super(Uninitialized()) {
    on<AuthenticationStarted>((event, emit) async {
      await _onAuthenticationStarted(event, emit);
    });
    on<SignInWithPhone>((event, emit) async {
      await _onSignInWithPhone(event, emit);
    });
    on<VerifyOtp>((event, emit) async {
      await _onVerifyOtp(event, emit);
    });
    on<SignOut>((event, emit) async {
      await _onSignOut(event, emit);
    });
    on<UpdateProfile>((event, emit) async {
      await _onUpdateProfile(event, emit);
    });
    on<AddRole>((event, emit) async {
      await _onAddRole(event, emit);
    });
    on<_AutoSignedIn>((event, emit) async {
      await BlockList.instance.load();
      await DemoAccount.instance.load();
      // Not awaited: the language only matters for later push messages.
      LanguageSync.save();
      emit(Authenticated(user: event.user));
    });

    // Android verified the number on its own: sign the user straight in,
    // whether they're still on the login screen or already on the code
    // screen. AppView's listener then takes them to Home.
    _autoSignInSub = _authRepository.autoSignIns.listen(
      (user) => add(_AutoSignedIn(user)),
    );
  }

  @override
  Future<void> close() {
    _autoSignInSub?.cancel();
    return super.close();
  }

  Future<void> _onAuthenticationStarted(
    AuthenticationStarted event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint('>>> AuthBloc: AuthenticationStarted received, emitting AuthLoading');
    emit(AuthLoading());

    try {
      debugPrint('>>> AuthBloc: calling getCurrentUser()');
      final user = await _authRepository.getCurrentUser();
      // uid only - the full UserModel includes the phone number and FCM
      // tokens, which must never end up in a log.
      debugPrint('>>> AuthBloc: getCurrentUser() returned uid: ${user?.uid}');

      if (user == null) {
        emit(Unauthenticated());
      } else {
        // Before Home loads, so blocked people are hidden from the start.
        await BlockList.instance.load();
        await DemoAccount.instance.load();
          // Not awaited: the language only matters for later push messages.
        LanguageSync.save();
        emit(Authenticated(user: user));
      }
      debugPrint('>>> AuthBloc: terminal state emitted');
    } catch (e, stackTrace) {
      debugPrint('>>> AuthBloc: getCurrentUser() threw: $e');
      debugPrint('$stackTrace');
      // Whatever the cause - Firebase not ready, network, permissions -
      // never leave the app stuck in AuthLoading with no terminal state.
      // Treat as unauthenticated so the user reaches the login screen
      // instead of a frozen splash screen.
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInWithPhone(
    SignInWithPhone event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final verificationId = await _authRepository.signInWithPhone(event.phoneNumber);
      _verificationId = verificationId;

      // Empty id = Android already verified the number and signed the
      // user in (see autoSignIns above) - there's no code to enter, so
      // don't open the code screen.
      if (verificationId.isEmpty) return;

      emit(PhoneVerificationSent(verificationId: verificationId));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onVerifyOtp(VerifyOtp event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      final user = await _authRepository.verifyOtp(
        event.verificationId,
        event.otpCode,
      );

      await BlockList.instance.load();
      await DemoAccount.instance.load();
      // Not awaited: the language only matters for later push messages.
      LanguageSync.save();
      emit(Authenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSignOut(SignOut event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _authRepository.signOut();
      BlockList.instance.clear();
      DemoAccount.instance.clear();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authRepository.updateUserProfile(
        displayName: event.displayName,
        photoUrl: event.photoUrl,
      );

      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(ProfileUpdated(user: user));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onAddRole(AddRole event, Emitter<AuthState> emit) async {
    try {
      await _authRepository.addRole(event.role);

      final user = await _authRepository.getCurrentUser();
      if (user != null && state is Authenticated) {
        emit(Authenticated(user: user));
      }
    } catch (e) {
      // Stay signed in. Emitting AuthError here used to replace the
      // Authenticated state, so every screen that checks "is the user
      // signed in" briefly thought they weren't.
      debugPrint('AddRole failed: $e');
    }
  }
}

/// Internal: Android verified the phone number automatically.
class _AutoSignedIn extends AuthEvent {
  final UserModel user;

  const _AutoSignedIn(this.user);

  @override
  List<Object?> get props => [user];
}