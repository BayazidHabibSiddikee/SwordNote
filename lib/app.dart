import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/canvas_screen.dart';
import 'ui/screens/cad_screen.dart';

class SwordTrackApp extends ConsumerWidget {
  const SwordTrackApp({super.key});

  static final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0EA5E9), // sky-500
    brightness: Brightness.dark,
    surface: const Color(0xFF0F172A),   // slate-900
    onSurface: const Color(0xFFE2E8F0), // slate-200
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
    );
    return MaterialApp(
      title: 'SwordTrack',
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/canvas': (_) => const CanvasScreen(),
        '/cad': (_) => const CadScreen(),
      },
    );
  }
}
