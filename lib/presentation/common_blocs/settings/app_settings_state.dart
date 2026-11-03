// lib/presentation/common_blocs/settings/app_settings_state.dart

import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:the_runner/data/local/search_radius_preference.dart';

class AppSettingsState extends Equatable {
  final Locale locale;
  final bool isDarkMode;
  final double searchRadiusKm;

  const AppSettingsState({
    required this.locale,
    required this.isDarkMode,
    required this.searchRadiusKm,
  });

  @override
  List<Object?> get props => [locale, isDarkMode, searchRadiusKm];
}

class AppSettingsInitial extends AppSettingsState {
  const AppSettingsInitial()
    : super(
        locale: const Locale('en'),
        isDarkMode: false,
        searchRadiusKm: SearchRadiusPreference.defaultRadiusKm,
      );
}