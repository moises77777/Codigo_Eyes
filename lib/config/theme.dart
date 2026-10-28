import 'package:flutter/material.dart';

/// Tema oscuro de alto contraste para personas con baja visión.
class EyesTheme {
  EyesTheme._();

  static const Color _fondo = Colors.black;
  static const Color _superficie = Color(0xFF121212);
  static const Color _acento = Color(0xFFFFD600);
  static const Color _texto = Colors.white;
  static const Color _textoSecundario = Colors.white70;
  static const Color _error = Colors.redAccent;

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _acento,
      brightness: Brightness.dark,
      surface: _superficie,
      primary: _acento,
      onPrimary: Colors.black,
      secondary: _acento,
      onSecondary: Colors.black,
      error: _error,
      onError: Colors.black,
      onSurface: _texto,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: _fondo,
        foregroundColor: _texto,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _texto,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _acento,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(64),
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _acento,
          minimumSize: const Size.fromHeight(64),
          side: const BorderSide(color: _acento, width: 2),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          color: _texto,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          color: _texto,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: _texto,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: _texto,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: _texto,
          fontSize: 18,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: _textoSecundario,
          fontSize: 16,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          color: _acento,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _superficie,
        labelStyle: const TextStyle(color: _textoSecundario, fontSize: 18),
        hintStyle: const TextStyle(color: _textoSecundario, fontSize: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _textoSecundario),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _textoSecundario),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _acento, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _textoSecundario,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _superficie,
        contentTextStyle: TextStyle(color: _texto, fontSize: 16),
      ),
    );
  }
}
