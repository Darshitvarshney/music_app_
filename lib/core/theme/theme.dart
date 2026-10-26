import 'package:flutter/material.dart';
import 'app_pallete.dart';

class AppTheme {
  // static final ThemeData lightTheme = ThemeData(colorScheme: ColorScheme.light());
  static OutlineInputBorder _border(Color borderColor) => OutlineInputBorder(
        borderSide: BorderSide(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(10),
      );
  static final ThemeData darkThemeMode = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: Pallete.backgroundColor, 
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.all(20),
      enabledBorder:  _border(Pallete.borderColor),
      focusedBorder: _border(Pallete.gradient2),
    ),
  );
}