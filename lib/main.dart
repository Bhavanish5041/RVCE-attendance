import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

// 1. GLOBAL VARIABLES
final supabase = Supabase.instance.client;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// 2. MAIN ENTRY POINT
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    // REPLACE THESE WITH YOUR ACTUAL KEYS IF THEY ARE DIFFERENT
    url: 'https://scvthcyknohcbdaqpynb.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjdnRoY3lrbm9oY2JkYXFweW5iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg3MjEyMTYsImV4cCI6MjA4NDI5NzIxNn0.UAcEDz05eBujbJEVtu7DzofqtYTYFQxA63zjRlTAQOU',
  );

  runApp(const AttendanceApp());
}

// 3. APP WIDGET
class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'RVCE Attendance',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.light),
            appBarTheme: AppBarTheme(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: AppBarTheme(backgroundColor: Colors.purple.shade900, foregroundColor: Colors.white),
          ),
          themeMode: currentMode,
          // 🟢 DEFINE ROUTES (Important for Logout to work)
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
          },
        );
      },
    );
  }
}