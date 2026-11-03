import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:the_runner/configs/application.dart';
import 'package:the_runner/data/local/pref.dart';
import 'package:the_runner/presentation/common_blocs/application/application_event.dart';
import 'package:the_runner/presentation/common_blocs/application/application_state.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth_event.dart';
import 'package:the_runner/presentation/common_blocs/common_bloc.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_event.dart';

class ApplicationBloc extends Bloc<ApplicationEvent, ApplicationState> {
  final Application application = Application();

  ApplicationBloc() : super(ApplicationInitial()) {
    on<SetupApplication>((event, emit) async {
      await _mapEventToState(emit);
    });
  }

  Future<void> _mapEventToState(Emitter<ApplicationState> emit) async {
    debugPrint('>>> ApplicationBloc: setup started');
    try {
      /// Setup SharedPreferences
      await application.setPreferences();
      debugPrint('>>> ApplicationBloc: preferences ready');

      /// Get old settings
      final oldLanguage = LocalPref.getString("language");
      debugPrint('>>> ApplicationBloc: oldLanguage = $oldLanguage');

      if (oldLanguage != null) {
        CommonBloc.appSettingsBloc.add(ChangeLanguage(Locale(oldLanguage)));
      }
    } catch (e, stackTrace) {
      debugPrint('ApplicationBloc setup error (non-fatal, continuing): $e');
      debugPrint('$stackTrace');
    }

    debugPrint('>>> ApplicationBloc: dispatching AuthenticationStarted');

    CommonBloc.authenticationBloc.add(AuthenticationStarted());

    debugPrint('>>> ApplicationBloc: emitting ApplicationCompleted');
    emit(ApplicationCompleted());
  }
}