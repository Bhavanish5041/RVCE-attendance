import 'package:flutter/material.dart';

class TeacherScreen extends StatelessWidget {
  const TeacherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Dashboard"),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text("Welcome, Teacher!", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}