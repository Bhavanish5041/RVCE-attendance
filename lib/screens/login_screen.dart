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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.school, size: 80, color: Colors.purple),
              const SizedBox(height: 24),
              const Text(
                'Attendance App',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isLoading ? null : _handleSignup,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Sign Up (Test Only)'),
              ),
              const SizedBox(height: 20),
              const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.all(8.0), child: Text("OR TEST OFFLINE")), Expanded(child: Divider())]),
              const SizedBox(height: 10),
              Row(
                children: [
                   Expanded(
                     child: TextButton.icon(
                       icon: const Icon(Icons.person_outline),
                       label: const Text("Guest Student"),
                       onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StudentScreen(studentEmail: "guest@student.com"))),
                     ),
                   ),
                   Expanded(
                     child: TextButton.icon(
                       icon: const Icon(Icons.school_outlined),
                       label: const Text("Guest Teacher"),
                       onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TeacherScreen())),
                     ),
                   ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
