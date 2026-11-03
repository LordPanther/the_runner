import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:the_runner/app_local_delegate.dart';

class Translate {
  final Locale locale;
  Map<String, String>? _localizedStrings;

  // English, used when the chosen language is missing a key, so a
  // missing translation shows English instead of a raw key like
  // "report_sent" on screen.
  Map<String, String>? _fallbackStrings;

  static const LocalizationsDelegate<Translate> delegate = AppLocaleDelegate();

  Translate(this.locale);

  static Translate of(BuildContext context) {
    return Localizations.of<Translate>(context, Translate)!;
  }

  static Future<Map<String, String>> _loadFile(String languageCode) async {
    final content = await rootBundle.loadString("assets/locale/$languageCode.json");
    final Map<String, dynamic> jsonMap = jsonDecode(content);
    return jsonMap.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<bool> load() async {
    _localizedStrings = await _loadFile(locale.languageCode);
    if (locale.languageCode != 'en') {
      _fallbackStrings = await _loadFile('en');
    }
    return true;
  }

  /// True if [key] is a translation key (in this language or English).
  bool has(String key) =>
      (_localizedStrings?.containsKey(key) ?? false) ||
      (_fallbackStrings?.containsKey(key) ?? false);

  String translate(String key) {
    return _localizedStrings?[key] ?? _fallbackStrings?[key] ?? key;
  }

  /// Like [translate], then fills {placeholders}:
  ///   "bids_count": "{count} bids"  ->  translateWith('bids_count', {'count': 3})
  /// Word order differs between languages, so values go INTO the
  /// sentence rather than being glued on before or after it.
  String translateWith(String key, Map<String, Object?> args) {
    var text = translate(key);
    args.forEach((name, value) {
      text = text.replaceAll('{$name}', '${value ?? ''}');
    });
    return text;
  }
}

/// Shorthand for screens: context.tr('key'), context.tr('key', {'n': 3}).
extension TranslateContext on BuildContext {
  String tr(String key, [Map<String, Object?>? args]) {
    final t = Translate.of(this);
    return args == null ? t.translate(key) : t.translateWith(key, args);
  }
}
