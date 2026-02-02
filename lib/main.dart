import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/student_screen.dart';
import 'screens/teacher_screen.dart';
import 'services/database_service.dart';

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
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B2072), // Figma Primary Purple
              primary: const Color(0xFF8B2072),
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: Colors.white,
            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF8B2072), 
              foregroundColor: Colors.white,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFCACACA).withValues(alpha: 0.3), // Light grey fill
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCACACA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCACACA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF8B2072), width: 2),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B2072),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: GoogleFonts.poppins(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B2072), brightness: Brightness.dark),
            scaffoldBackgroundColor: const Color(0xFF121212),
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.dark().textTheme,
            ),
            appBarTheme: AppBarTheme(backgroundColor: Colors.purple.shade900, foregroundColor: Colors.white),
          ),
          themeMode: currentMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/login': (context) => const LoginScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Widget? _home;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _home = const LoginScreen();
          _isLoading = false;
        });
        return;
      }

      // Check role
      final role = await DatabaseService().getUserRole();
      if (role == 'teacher') {
        setState(() {
          _home = const TeacherScreen();
          _isLoading = false;
        });
      } else {
        setState(() {
          _home = StudentScreen(studentEmail: session.user.email ?? "student@test.com");
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _home = const LoginScreen();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _home!;
  }
}