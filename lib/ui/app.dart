import 'package:flutter/material.dart';

class AppRoot extends StatelessWidget {
  final Widget home;
  const AppRoot({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0D2A4A);
    const primaryContainer = Color(0xFF16406F);
    const secondary = Color(0xFF00C2C7);
    const secondaryContainer = Color(0xFF6FE4E7);
    const background = Color(0xFFF7F9FC);

    final colorScheme = const ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      secondary: secondary,
      onSecondary: Color(0xFF062238),
      secondaryContainer: secondaryContainer,
      background: background,
      onBackground: primary,
      surface: Colors.white,
      onSurface: primary,
    );

    return MaterialApp(
      title: 'ARXML Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: primary.withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(color: Colors.white),
        ),
      ),
      home: home,
    );
  }
}
