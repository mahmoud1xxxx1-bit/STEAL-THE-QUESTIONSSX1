import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'v2_active_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const StealTheQuestionsApp());
}

class StealTheQuestionsApp extends StatelessWidget {
  const StealTheQuestionsApp({super.key});

  static const Color royalBlue = Color(0xFF246BFD);
  static const Color playfulPurple = Color(0xFF7C4DFF);
  static const Color warmGold = Color(0xFFFFC83D);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color ink = Color(0xFF18234A);
  static const Color softInk = Color(0xFF67729A);
  static const Color canvas = Color(0xFFF5F8FF);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: royalBlue,
      brightness: Brightness.light,
      primary: royalBlue,
      secondary: playfulPurple,
      tertiary: warmGold,
      error: coral,
    );

    return MaterialApp(
      title: 'STEAL THE QUESTIONS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF8F6FF),
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: ink, fontWeight: FontWeight.w900),
          headlineMedium: TextStyle(color: ink, fontWeight: FontWeight.w900),
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
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          height: 72,
          indicatorColor: const Color(0xFFECE6FF),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? playfulPurple : softInk,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            );
          }),
        ),
      ),
      home: const StealQuestionsV2App(),
    );
  }
}
