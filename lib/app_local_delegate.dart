import 'package:flutter/material.dart';
import 'package:the_runner/configs/language.dart';

import 'utils/translate.dart';

class AppLocaleDelegate extends LocalizationsDelegate<Translate> {
  const AppLocaleDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLanguage.supportLanguage.contains(locale);
  }

  @override
  Future<Translate> load(Locale locale) async {
    final localizations = Translate(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocaleDelegate old) => false;
}