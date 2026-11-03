import 'dart:ui';
 
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/data/local/pref.dart';
import 'package:the_runner/data/local/search_radius_preference.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_event.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_state.dart';
import 'package:the_runner/data/services/language_sync.dart';
 
class AppSettingsBloc extends Bloc<AppSettingsEvent, AppSettingsState> {
  AppSettingsBloc() : super(const AppSettingsInitial()) {
    on<LoadSettings>((event, emit) {
      final savedLanguage = LocalPref.getString('language');
      // NOTE: was previously hardcoded to `true` regardless of what was
      // saved. There's also no dark theme built yet (AppTheme has a
      // single light/cream theme) - this reads the persisted value for
      // when a dark theme does get built, but defaults to false since
      // that's what actually reflects the app's current visual state.
      final savedIsDarkMode = LocalPref.getBool('isDarkMode') ?? false;
 
      emit(
        AppSettingsState(
          locale: savedLanguage != null
              ? Locale(savedLanguage)
              : const Locale('en'),
          isDarkMode: savedIsDarkMode,
          searchRadiusKm: SearchRadiusPreference.get(),
        ),
      );
    });
 
    on<ChangeLanguage>((event, emit) {
      LocalPref.setString('language', event.locale.languageCode);
      LanguageSync.save(event.locale.languageCode);
      emit(
        AppSettingsState(
          locale: event.locale,
          isDarkMode: state.isDarkMode,
          searchRadiusKm: state.searchRadiusKm,
        ),
      );
    });
 
    on<ChangeTheme>((event, emit) {
      LocalPref.setBool('isDarkMode', event.isDarkMode);
      emit(
        AppSettingsState(
          locale: state.locale,
          isDarkMode: event.isDarkMode,
          searchRadiusKm: state.searchRadiusKm,
        ),
      );
    });
 
    on<ChangeSearchRadius>((event, emit) {
      SearchRadiusPreference.set(event.radiusKm);
      emit(
        AppSettingsState(
          locale: state.locale,
          isDarkMode: state.isDarkMode,
          searchRadiusKm: event.radiusKm,
        ),
      );
    });
  }
}
 





















































