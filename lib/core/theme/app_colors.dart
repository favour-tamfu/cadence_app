import 'package:flutter/material.dart';

class AppColors {
  // Brand primaries
  static const Color midnight   = Color(0xFF0D1B2A);
  static const Color midnight2  = Color(0xFF142234);
  static const Color midnight3  = Color(0xFF1C2E42);
  static const Color slate      = Color(0xFF2C3E52);
  static const Color amber      = Color(0xFFC47D0E);
  static const Color amberLight = Color(0xFFF0A830);
  static const Color cream      = Color(0xFFF7F2EA);
  static const Color muted      = Color(0xFF8A9BB0);

  // Semantic
  static const Color success = Color(0xFF1D9E75);
  static const Color error   = Color(0xFFE24B4A);
  static const Color warning = Color(0xFFBA7517);

  // Opacity helpers
  static Color creamFaint  = cream.withValues(alpha: 0.08);
  static Color creamDim    = cream.withValues(alpha: 0.65);
  static Color amberDim    = amber.withValues(alpha: 0.12);
  static Color midnightDim = midnight.withValues(alpha: 0.08);
}
