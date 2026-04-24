import 'package:flutter/material.dart';
import 'app_shell/tab_screen.dart';

class DeenLabApp extends StatelessWidget {
  const DeenLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeenLab',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // 🌞 LIGHT THEME
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F9D8A),
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor: const Color(0xFFF5F7F6),

        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),

        // FIX: CardTheme → CardThemeData
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),

      // 🌙 DARK THEME
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1ABC9C),
          secondary: Color(0xFFD4AF37),
        ),

        scaffoldBackgroundColor: const Color(0xFF0E1117),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF0E1117),
          elevation: 0,
        ),

        // FIX: CardTheme → CardThemeData
        cardTheme: CardThemeData(
          color: const Color(0xFF161B22),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1ABC9C),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // FIX: TabBarTheme → TabBarThemeData
        tabBarTheme: const TabBarThemeData(
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),

      home: const TabScreen(),
    );
  }
}
