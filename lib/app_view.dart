import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:the_runner/configs/application.dart';
import 'package:the_runner/configs/language.dart';
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/configs/theme.dart';
import 'package:the_runner/data/services/push_notification_service.dart';
import 'package:the_runner/presentation/common_blocs/application/application_bloc.dart';
import 'package:the_runner/presentation/common_blocs/application/application_event.dart';
import 'package:the_runner/presentation/common_blocs/application/application_state.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth_bloc.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth_state.dart';
import 'package:the_runner/presentation/common_blocs/common_bloc.dart';
import 'package:the_runner/presentation/common_blocs/profile/profile_bloc.dart';
import 'package:the_runner/presentation/common_blocs/profile/profile_event.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_bloc.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_state.dart';
import 'package:the_runner/utils/translate.dart';

class AppView extends StatefulWidget {
  const AppView({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  _AppViewState createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  GlobalKey<NavigatorState> get _navigatorKey => AppView.navigatorKey;

  NavigatorState? get _navigator => _navigatorKey.currentState;

  Timer? _pollTimer;
  bool _reachedTerminalState = false;

  @override
  void initState() {
    super.initState();
    CommonBloc.applicationBloc.add(SetupApplication());

    _pollTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final navigated = _evaluateNavigation(context);
      if (navigated) {
        _reachedTerminalState = true;
        timer.cancel();
      }
    });

    Timer(const Duration(seconds: 10), () {
      if (!_reachedTerminalState) _pollTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    CommonBloc.dispose();
    super.dispose();
  }

  // The AuthBloc state seen by the listener last time, so it can tell a
  // real sign-in/sign-out apart from a change to an already signed-in
  // user.
  AuthState? _lastAuthState;

  bool onNavigate(String route) {
    if (_navigator == null) return false;
    _navigator!.pushNamedAndRemoveUntil(route, (route) => false);
    return true;
  }

  void loadData() {
    // Only load data when authenticated
    BlocProvider.of<ProfileBloc>(context).add(LoadProfile());
    PushNotificationService().initialize();
  }

  bool _evaluateNavigation(BuildContext context) {
    final applicationState = context.read<ApplicationBloc>().state;
    if (applicationState is! ApplicationCompleted) {
      return false;
    }

    final authState = context.read<AuthBloc>().state;

    if (authState is Unauthenticated) {
      return onNavigate(AppRouter.login);
    } else if (authState is Authenticated) {
      loadData();
      return onNavigate(AppRouter.home);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApplicationBloc, ApplicationState>(
      builder: (context, applicationState) {
        return BlocBuilder<AppSettingsBloc, AppSettingsState>(
          builder: (context, settingsState) {
            return MaterialApp(
              navigatorKey: _navigatorKey,
              debugShowCheckedModeBanner: Application.debug,
              title: Application.title,
              theme: AppTheme.currentTheme,
              onGenerateRoute: AppRouter.generateRoute,
              initialRoute: AppRouter.splash,
              locale: settingsState.locale,
              supportedLocales: AppLanguage.supportLanguage,
              localizationsDelegates: [
                Translate.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                return MultiBlocListener(
                  listeners: [
                    BlocListener<ApplicationBloc, ApplicationState>(
                      listener: (context, state) =>
                          _evaluateNavigation(context),
                    ),
                    BlocListener<AuthBloc, AuthState>(
                      listener: (context, state) {
                        final previous = _lastAuthState;
                        _lastAuthState = state;
                        // Still signed in, only the user changed (e.g. they
                        // just finished runner onboarding): refresh the
                        // profile, but DON'T navigate. Re-navigating to Home
                        // here would wipe the screen stack mid-flow.
                        if (previous is Authenticated && state is Authenticated) {
                          BlocProvider.of<ProfileBloc>(context).add(LoadProfile());
                          return;
                        }
                        _evaluateNavigation(context);
                      },
                    ),
                  ],
                  child: child!,
                );
              },
            );
          },
        );
      },
    );
  }
}
