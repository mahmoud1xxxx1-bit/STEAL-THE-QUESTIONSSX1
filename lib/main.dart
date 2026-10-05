import 'package:flutter/material.dart';
import 'football_design_app_v2.dart';

void main() {
  runApp(const StealTheQuestionsApp());
}

class StealTheQuestionsApp extends StatelessWidget {
  const StealTheQuestionsApp({super.key});

  static const Color royalBlue = Color(0xFF246BFD);
  static const Color skyBlue = Color(0xFF42B7FF);
  static const Color playfulPurple = Color(0xFF7C4DFF);
  static const Color warmGold = Color(0xFFFFC83D);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color ink = Color(0xFF18234A);
  static const Color softInk = Color(0xFF67729A);
  static const Color canvas = Color(0xFFF5F8FF);
  static const Color surface = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: royalBlue,
      brightness: Brightness.light,
      primary: royalBlue,
      secondary: playfulPurple,
      tertiary: warmGold,
      surface: surface,
      error: coral,
    );

    return MaterialApp(
      title: 'STEAL THE QUESTIONS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: canvas,
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: ink, fontWeight: FontWeight.w900, letterSpacing: -0.6),
          headlineMedium: TextStyle(color: ink, fontWeight: FontWeight.w900, letterSpacing: -0.4),
          titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w900),
          titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w800),
          bodyLarge: TextStyle(color: ink, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: softInk, fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          elevation: 12,
          height: 68,
          indicatorColor: const Color(0xFFE9E2FF),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? playfulPurple : softInk,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(color: selected ? playfulPurple : softInk, size: selected ? 26 : 23);
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: royalBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 50),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: royalBlue,
            side: const BorderSide(color: Color(0xFFD8E2FF), width: 1.3),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E9F8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E9F8)),
          ),
        ),
        dividerColor: const Color(0xFFE7ECF7),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: skyBlue,
          linearTrackColor: Color(0xFFE3EBFA),
        ),
      ),
      home: const FootballDesignAppV2(),
    );
  }
}
