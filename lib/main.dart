import 'package:flutter/material.dart';
import 'product_app.dart';

void main() {
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STEAL THE QUESTIONS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF3C86B),
          secondary: Color(0xFF78D9D0),
          surface: Color(0xFF121926),
        ),
        fontFamily: 'Arial',
      ),
      home: const StealTheQuestionsHome(),
    );
  }
}
