import 'package:flutter/material.dart';

/// 品牌色：青柠主色（#7AC70C）+ 火焰橙（连胜/激励）。
/// Hero 渐变：lime → teal → cyan（今日文章卡）。
abstract final class AppColors {
  // —— 青柠 ——
  static const primary = Color(0xFF7AC70C);
  static const primaryDeep = Color(0xFF4D7C0F);
  static const primaryMid = Color(0xFFA3E635);
  static const primarySoft = Color(0xFFF7FEE7);
  static const primaryBorder = Color(0xFFD9F99D);
  static const primaryMuted = Color(0xFFBEF264);

  /// 深色卡片底（非渐变场景仍可用）
  static const hero = Color(0xFF365314);
  static const heroLabel = Color(0xFFBEF264);
  static const heroMeta = Color(0xFFA3E635);

  // —— Hero 渐变（今日文章卡）——
  static const lime = Color(0xFFA6E22E);
  static const teal = Color(0xFF3FC7B8);
  static const cyan = Color(0xFF29B6D8);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lime, teal, cyan],
    stops: [0.0, 0.48, 1.0],
  );

  // —— 火焰橙：连胜 / 激励 / CTA 字色 ——
  static const accent = Color(0xFFF25B0B);
  static const accentDeep = Color(0xFFE8520C);
  static const accentSoft = Color(0xFFFFF7ED);
  static const accentBorder = Color(0xFFFED7AA);

  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const bg = Color(0xFFF8FAFC);
}

