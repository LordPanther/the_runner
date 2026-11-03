import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/presentation/common_blocs/application/application_bloc.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth_bloc.dart';
import 'package:the_runner/presentation/common_blocs/location/location_bloc.dart';
import 'package:the_runner/presentation/common_blocs/notification/notification_bloc.dart';
import 'package:the_runner/presentation/common_blocs/profile/profile_bloc.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_bloc.dart';
class CommonBloc {
  /// Bloc instances
  static final applicationBloc = ApplicationBloc();
  static final authenticationBloc = AuthBloc();
  static final profileBloc = ProfileBloc();
  static final locationBloc = LocationBloc();
  static final appSettingsBloc = AppSettingsBloc();
  static final notificationBloc = NotificationBloc();

  static final List<BlocProvider> blocProviders = [
    BlocProvider<ApplicationBloc>(
      create: (context) => applicationBloc,
    ),
    BlocProvider<AuthBloc>(
      create: (context) => authenticationBloc,
    ),
    BlocProvider<ProfileBloc>(
      create: (context) => profileBloc,
    ),
    BlocProvider<LocationBloc>(
      create: (context) => locationBloc,
    ),
    BlocProvider<AppSettingsBloc>(
      create: (context) => appSettingsBloc,
    ),
    BlocProvider<NotificationBloc>(
      create: (context) => notificationBloc,
    ),
  ];

  /// Dispose
  static void dispose() {
    applicationBloc.close();
    authenticationBloc.close();
    profileBloc.close();
    locationBloc.close();
    appSettingsBloc.close();
    notificationBloc.close();
  }

  /// Singleton factory
  static final CommonBloc _instance = CommonBloc._internal();

  factory CommonBloc() {
    return _instance;
  }

  CommonBloc._internal();
}