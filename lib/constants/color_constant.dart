import 'package:flutter/material.dart';

class ColorConst {
  // ── Brand ──────────────────────────────────────────────────
  static const primaryColor = Color(0xFF8B5A2B); // Warm Timber
  static const secondaryColor = Color(0xFF4A7C59); // Field Green
  static const accentColor = Color(0xFFE67E22); // Sunset Orange (CTAs)

  // ── Surfaces ───────────────────────────────────────────────
  static const backgroundColor = Color(0xFFFDFBF7); // Cream
  static const surfaceColor = Color(0xFFFFFFFF);
  static const cardShadowColor = Color(0x14000000); // rgba(0,0,0,0.08)
  static const borderColor = Color(0xFFE5E1D8);
  static const dividerColor = Color(0xFFE5E1D8);

  // ── Text ───────────────────────────────────────────────────
  static const textColor = Color(0xFF2C2C2C); // Dark Charcoal (primary text)
  static const textSecondaryColor = Color(0xFF6B6B6F); // Stone Gray

  // ── Status ─────────────────────────────────────────────────
  static const successColor = Color(0xFF2E7D32); // Forest Green (Open)
  static const errorColor = Color(0xFFC62828); // Rust Red (Closed)
  static const warningColor = Color(0xFFF9A825); // Harvest Gold

  ///Singleton factory
  static final ColorConst _instance = ColorConst._internal();

  factory ColorConst() {
    return _instance;
  }

  ColorConst._internal();
}

const mAnimationDuration = Duration(milliseconds: 200);
