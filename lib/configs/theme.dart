import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';

class AppTheme {
  static final ThemeData currentTheme = ThemeData(
    scaffoldBackgroundColor: ColorConst.backgroundColor,
    fontFamily: GoogleFonts.inter().fontFamily,
    appBarTheme: _appBarTheme,
    textTheme: _textTheme,
    colorScheme: _colorScheme,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColorConst.accentColor,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    inputDecorationTheme: _inputDecorationThem,
  );

  static const _colorScheme = ColorScheme.light(
    primary: ColorConst.primaryColor,
    secondary: ColorConst.secondaryColor,
    error: ColorConst.errorColor,
    surface: ColorConst.surfaceColor,
  );

  static final _appBarTheme = AppBarTheme(
    backgroundColor: Colors.white,
    shadowColor: ColorConst.cardShadowColor,
    elevation: 0.4,
    iconTheme: IconThemeData(color: ColorConst.textColor),
    actionsIconTheme: IconThemeData(color: ColorConst.textColor),
    centerTitle: true,
    titleTextStyle: FontConst.BOLD_DEFAULT_18,
  );

  static final _textTheme = TextTheme(
    bodySmall: TextStyle(color: ColorConst.textColor),
    bodyMedium: TextStyle(color: ColorConst.textColor),
    bodyLarge: TextStyle(color: ColorConst.textColor),
  );

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: ColorConst.secondaryColor,
      foregroundColor: Colors.white,
      minimumSize: Size(double.infinity, SizeConfig.defaultSize * 4.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: FontConst.MEDIUM_WHITE_16,
    ),
  );

  static final _outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ColorConst.primaryColor,
      side: const BorderSide(color: ColorConst.primaryColor),
      minimumSize: Size(double.infinity, SizeConfig.defaultSize * 4.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: FontConst.MEDIUM_PRIMARY_16,
    ),
  );

  static final _inputDecorationThem = InputDecorationTheme(
    contentPadding:
        EdgeInsets.symmetric(horizontal: SizeConfig.defaultPadding * 1.2),
    filled: true,
    fillColor: ColorConst.surfaceColor,
    border: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: ColorConst.borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: ColorConst.borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: const BorderSide(color: ColorConst.primaryColor, width: 1.5),
    ),
    hintStyle: FontConst.REGULAR_SECONDARY_14,
  );

  /// Singleton factory
  static final AppTheme _instance = AppTheme._internal();

  factory AppTheme() {
    return _instance;
  }

  AppTheme._internal();
}
