import 'package:flutter/material.dart';

/// Палитра «Заветная Рыбалка»: графит/сталь + тёплый янтарь как акцент клёва/награды.
abstract final class AppColors {
  static const background = Color(0xFF0B0E12);
  static const surface = Color(0xFF12161B);
  static const surfaceHigh = Color(0xFF1A1F25);
  static const steel = Color(0xFFC9CDD2);
  static const accent = Color(0xFFE6A23C); // янтарь
  static const danger = Color(0xFFE5483B); // поклёвка/обрыв
  static const success = Color(0xFF4CAF50); // зелёная зона
}
