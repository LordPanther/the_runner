// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';

/// Type system per design brief:
/// - Headings -> Poppins Bold (slightly rustic, modern)
/// - Body     -> Inter Regular (clean, readable)
/// - Small    -> Inter Medium
class FontConst {
  static final REGULAR = GoogleFonts.inter(
    fontWeight: FontWeight.w400,
    color: Colors.black,
    fontSize: SizeConfig.defaultSize * 1.4,
  );

  static final MEDIUM = GoogleFonts.inter(
    fontWeight: FontWeight.w500,
    color: Colors.black,
    fontSize: SizeConfig.defaultSize * 1.4,
  );

  static final BOLD = GoogleFonts.poppins(
    fontWeight: FontWeight.w700,
    color: Colors.black,
    fontSize: SizeConfig.defaultSize * 1.4,
  );

  //REGULAR
  static final REGULAR_DEFAULT = REGULAR.copyWith(color: ColorConst.textColor);
  static final REGULAR_DEFAULT_16 =
      REGULAR_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final REGULAR_DEFAULT_18 =
      REGULAR_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final REGULAR_DEFAULT_20 =
      REGULAR_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 2);

  static final REGULAR_SECONDARY =
      REGULAR.copyWith(color: ColorConst.textSecondaryColor);
  static final REGULAR_SECONDARY_12 =
      REGULAR_SECONDARY.copyWith(fontSize: SizeConfig.defaultSize * 1.2);
  static final REGULAR_SECONDARY_14 =
      REGULAR_SECONDARY.copyWith(fontSize: SizeConfig.defaultSize * 1.4);

  static final REGULAR_PRIMARY =
      REGULAR.copyWith(color: ColorConst.primaryColor);
  static final REGULAR_PRIMARY_16 =
      REGULAR_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final REGULAR_PRIMARY_18 =
      REGULAR_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final REGULAR_PRIMARY_20 =
      REGULAR_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 2);

  static final REGULAR_WHITE = REGULAR.copyWith(color: Colors.white);
  static final REGULAR_WHITE_16 =
      REGULAR_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final REGULAR_WHITE_18 =
      REGULAR_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final REGULAR_WHITE_20 =
      REGULAR_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 2);

  //MEDIUM (SEMIBOLD)
  static final MEDIUM_DEFAULT = MEDIUM.copyWith(color: ColorConst.textColor);
  static final MEDIUM_DEFAULT_16 =
      MEDIUM_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final MEDIUM_DEFAULT_18 =
      MEDIUM_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final MEDIUM_DEFAULT_20 =
      MEDIUM_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 2);

  static final MEDIUM_SECONDARY =
      MEDIUM.copyWith(color: ColorConst.textSecondaryColor);
  static final MEDIUM_SECONDARY_12 =
      MEDIUM_SECONDARY.copyWith(fontSize: SizeConfig.defaultSize * 1.2);
  static final MEDIUM_SECONDARY_14 =
      MEDIUM_SECONDARY.copyWith(fontSize: SizeConfig.defaultSize * 1.4);

  static final MEDIUM_PRIMARY =
      MEDIUM.copyWith(color: ColorConst.primaryColor);
  static final MEDIUM_PRIMARY_16 =
      MEDIUM_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final MEDIUM_PRIMARY_18 =
      MEDIUM_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final MEDIUM_PRIMARY_20 =
      MEDIUM_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 2);
  static final MEDIUM_PRIMARY_24 =
      MEDIUM_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 2.4);

  static final MEDIUM_SUCCESS = MEDIUM.copyWith(color: ColorConst.successColor);
  static final MEDIUM_SUCCESS_12 =
      MEDIUM_SUCCESS.copyWith(fontSize: SizeConfig.defaultSize * 1.2);

  static final MEDIUM_ERROR = MEDIUM.copyWith(color: ColorConst.errorColor);
  static final MEDIUM_ERROR_12 =
      MEDIUM_ERROR.copyWith(fontSize: SizeConfig.defaultSize * 1.2);

  static final MEDIUM_WHITE = MEDIUM.copyWith(color: Colors.white);
  static final MEDIUM_WHITE_16 =
      MEDIUM_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final MEDIUM_WHITE_18 =
      MEDIUM_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final MEDIUM_WHITE_20 =
      MEDIUM_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 2);

  //BOLD (headings - Poppins)
  static final BOLD_DEFAULT = BOLD.copyWith(color: ColorConst.textColor);
  static final BOLD_DEFAULT_16 =
      BOLD_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final BOLD_DEFAULT_18 =
      BOLD_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final BOLD_DEFAULT_20 =
      BOLD_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 2);
  static final BOLD_DEFAULT_24 =
      BOLD_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 2.4);
  static final BOLD_DEFAULT_26 =
      BOLD_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 2.6);
  static final BOLD_DEFAULT_28 =
      BOLD_DEFAULT.copyWith(fontSize: SizeConfig.defaultSize * 2.8);

  static final BOLD_PRIMARY = BOLD.copyWith(color: ColorConst.primaryColor);
  static final BOLD_PRIMARY_16 =
      BOLD_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final BOLD_PRIMARY_18 =
      BOLD_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final BOLD_PRIMARY_20 =
      BOLD_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 2);
  static final BOLD_PRIMARY_24 =
      BOLD_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 2.4);
  static final BOLD_PRIMARY_26 =
      BOLD_PRIMARY.copyWith(fontSize: SizeConfig.defaultSize * 2.6);

  static final BOLD_SECONDARY = BOLD.copyWith(color: ColorConst.secondaryColor);
  static final BOLD_SECONDARY_16 =
      BOLD_SECONDARY.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final BOLD_SECONDARY_20 =
      BOLD_SECONDARY.copyWith(fontSize: SizeConfig.defaultSize * 2);

  static final BOLD_ACCENT = BOLD.copyWith(color: ColorConst.accentColor);
  static final BOLD_ACCENT_16 =
      BOLD_ACCENT.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final BOLD_ACCENT_20 =
      BOLD_ACCENT.copyWith(fontSize: SizeConfig.defaultSize * 2);

  static final BOLD_WHITE = BOLD.copyWith(color: Colors.white);
  static final BOLD_WHITE_16 =
      BOLD_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 1.6);
  static final BOLD_WHITE_18 =
      BOLD_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 1.8);
  static final BOLD_WHITE_20 =
      BOLD_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 2);
  static final BOLD_WHITE_26 =
      BOLD_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 2.6);
  static final BOLD_WHITE_32 =
      BOLD_WHITE.copyWith(fontSize: SizeConfig.defaultSize * 3.2);

  ///Singleton factory
  static final FontConst _instance = FontConst._internal();

  factory FontConst() {
    return _instance;
  }

  FontConst._internal();
}
