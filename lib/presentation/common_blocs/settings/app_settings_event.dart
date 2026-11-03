// lib/presentation/common_blocs/settings/app_settings_event.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class AppSettingsEvent extends Equatable {
  const AppSettingsEvent();
  @override
  List<Object?> get props => [];
}

class ChangeLanguage extends AppSettingsEvent {
  final Locale locale;
  const ChangeLanguage(this.locale);
  @override
  List<Object?> get props => [locale];
}

class ChangeTheme extends AppSettingsEvent {
  final bool isDarkMode;
  const ChangeTheme(this.isDarkMode);
  @override
  List<Object?> get props => [isDarkMode];
}

class ChangeSearchRadius extends AppSettingsEvent {
  final double radiusKm;
  const ChangeSearchRadius(this.radiusKm);
  @override
  List<Object?> get props => [radiusKm];
}

class LoadSettings extends AppSettingsEvent {}