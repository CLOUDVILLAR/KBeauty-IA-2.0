import 'package:flutter/material.dart';

class KBeautyColors {
  static const Color rojo = Color(0xFFDC1015);
  static const Color rojoOscuro = Color(0xFF9F080C);
  static const Color rojoSuave = Color(0xFFFFE8EA);
  static const Color rosaMuySuave = Color(0xFFFFF6F7);
  static const Color fondo = Color(0xFFFAFAFC);
  static const Color texto = Color(0xFF202027);
  static const Color textoSuave = Color(0xFF7B7B88);
  static const Color borde = Color(0xFFF0E3E5);
  static const Color card = Color(0xFFFFFFFF);
}

ThemeData crearTemaApp() {
  const rojoMarca = KBeautyColors.rojo;
  final esquema = ColorScheme.fromSeed(
    seedColor: rojoMarca,
    primary: rojoMarca,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema.copyWith(
      primary: rojoMarca,
      secondary: rojoMarca,
      surface: KBeautyColors.card,
      error: const Color(0xFFB42318),
    ),
    scaffoldBackgroundColor: KBeautyColors.fondo,
    fontFamily: null,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: KBeautyColors.texto, fontWeight: FontWeight.w900),
      headlineMedium: TextStyle(color: KBeautyColors.texto, fontWeight: FontWeight.w900),
      titleLarge: TextStyle(color: KBeautyColors.texto, fontWeight: FontWeight.w900),
      titleMedium: TextStyle(color: KBeautyColors.texto, fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(color: KBeautyColors.texto),
      bodyMedium: TextStyle(color: KBeautyColors.texto),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: KBeautyColors.fondo,
      foregroundColor: KBeautyColors.texto,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: KBeautyColors.texto,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: rojoMarca),
    iconTheme: const IconThemeData(color: KBeautyColors.texto),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: KBeautyColors.texto,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: rojoMarca,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE9D8DA),
        disabledForegroundColor: KBeautyColors.textoSuave,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        minimumSize: const Size.fromHeight(54),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: rojoMarca,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        minimumSize: const Size.fromHeight(54),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: rojoMarca,
        side: const BorderSide(color: Color(0xFFFFC5C8), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        minimumSize: const Size.fromHeight(50),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: rojoMarca,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(color: KBeautyColors.textoSuave, fontWeight: FontWeight.w700),
      hintStyle: const TextStyle(color: KBeautyColors.textoSuave),
      prefixIconColor: rojoMarca,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: KBeautyColors.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: rojoMarca, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: KBeautyColors.borde),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFB42318)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: KBeautyColors.borde),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: rojoMarca,
      unselectedItemColor: KBeautyColors.textoSuave,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}
