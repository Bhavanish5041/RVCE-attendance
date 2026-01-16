import 'package:flutter/material.dart';
import 'student_screen.dart';
import 'teacher_screen.dart'; 

// GLOBAL THEME CONTROLLER
// This allows any page to change the theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap MaterialApp in a listener so it rebuilds when theme changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'RVCE Attendance',
          
          // LIGHT THEME
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.light),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
            ),
          ),
          
          // DARK THEME
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark),
            scaffoldBackgroundColor: const Color(0xFF121212), // Pure black background
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.purple.shade900,
              foregroundColor: Colors.white,
            ),
          ),
          
          themeMode: currentMode, // Switches between light and dark
          home: const LoginScreen(),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();

  void _handleLogin() {
    String email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showError("Please enter an email address");
      return;
    }

    if (!email.endsWith('@rvce.edu.in')) {
      _showError("Access Denied: Please use your official @rvce.edu.in email");
      return;
    }

    if (email.contains('.ai23') || 
        email.contains('.ai24') || 
        email.contains('.ec23')) {
      
      // PASS THE EMAIL TO THE NEXT SCREEN
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentScreen(studentEmail: email),
        ),
      );
      
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TeacherScreen()),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RVCE Login"), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.purple.shade100,
                child: const Icon(Icons.school_rounded, size: 60, color: Colors.purple),
              ),
              const SizedBox(height: 30),
              const Text("Welcome to RVCE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "College Email ID",
                  hintText: "rahul.ai23@rvce.edu.in",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Secure Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}