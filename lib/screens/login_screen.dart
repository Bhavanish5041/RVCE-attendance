import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import 'student_screen.dart';
import 'teacher_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'teacher@test.com');
  final _passwordController = TextEditingController(text: 'password123');
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }

      // 1. Supabase Auth
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) throw 'Login failed';

      _navigateBasedOnRole(email);

    } catch (e) {
      if (mounted) {
        String message = e.toString();
        // Check for common Supabase login errors
        if (message.contains("Invalid login credentials") || message.contains("Invalid credentials")) {
          message = "Account not found. Please tap 'Sign Up' first.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter email and password to sign up';
      }

      // 1. Sign Up
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) throw 'Signup failed';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created! Logging in..."), backgroundColor: Colors.green),
        );
      }
      
      // 2. Auto Login & Navigate
      _navigateBasedOnRole(email);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Signup Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateBasedOnRole(String email) async {
      // Check Role
      final role = await DatabaseService().getUserRole();

      if (!mounted) return;

      if (role == 'teacher') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TeacherScreen()),
        );
      } else {
        // Pass email to StudentScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StudentScreen(studentEmail: email)),
        );
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Header
              Text(
                'Welcome Back!\nSign in to continue!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.3,
                    ),
              ),
              const SizedBox(height: 40),



              // Email Input
              const Text(
                'Username / Email',
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: Color(0xFF939393),
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 24),

              // Password Input
              const Text(
                'Password',
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: Color(0xFF939393),
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  hintText: 'Enter your password',
                   contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                obscureText: true,
              ),

              const SizedBox(height: 40),

              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: const Color(0xFF8B2072),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Log in',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
                      ),
              ),

              const SizedBox(height: 24),

              // Footer Links
              TextButton(
                onPressed: () {
                   // TODO: Implement Forgot Password
                },
                child: const Text(
                  'Forget password?',
                  style: TextStyle(
                    color: Color(0xFF8B2072),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                        color: Color(0xFF8B2072),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  GestureDetector(
                    onTap: _handleSignup,
                     child: const Text(
                      "Sign up",
                      style: TextStyle(
                          color: Color(0xFFFF0000), // Red from Figma
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              // Guest Access (Testing)
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StudentScreen(studentEmail: "guest@student.com"))),
                 child: const Text("Guest Student Access (Test)", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TeacherScreen())), // Quick Teacher Access
                 child: const Text("Guest Teacher Access (Test)", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
