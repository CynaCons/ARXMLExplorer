import 'package:flutter/material.dart';

class AppRoot extends StatelessWidget {
  final Widget home;
  const AppRoot({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0D47A1), // A deep, professional blue
      brightness: Brightness.light,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF42A5F5), // A slightly brighter blue for dark mode
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'ARXML Explorer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Or ThemeMode.light, ThemeMode.dark
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: lightScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.primary,
          foregroundColor: lightScheme.onPrimary,
          elevation: 0,
          iconTheme: IconThemeData(color: lightScheme.onPrimary),
          titleTextStyle: TextStyle(
            color: lightScheme.onPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: lightScheme.primary.withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: TextStyle(color: lightScheme.onPrimary),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: darkScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.primary,
          foregroundColor: darkScheme.onPrimary,
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: darkScheme.primary.withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: TextStyle(color: darkScheme.onPrimary),
        ),
      ),
      home: home,
    );
  }
}
