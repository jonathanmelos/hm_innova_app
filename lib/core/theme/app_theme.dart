import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A73E8), // azul HM INNOVA
        brightness: Brightness.light,
        fontFamily: 'Roboto',
      );
}
