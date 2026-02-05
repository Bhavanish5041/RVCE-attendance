import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'login_screen.dart';
import 'request_correction_page.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final String section;
  final int semester;

  const ProfilePage({
    super.key, 
    required this.name, 
    required this.email,
    this.section = "A",
    this.semester = 1,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == widget.name) {
      setState(() => _isEditing = false);
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('students')
            .update({'name': newName})
            .eq('user_id', user.id);
            
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Name updated! (Restart app to see changes everywhere)")),
           );
           setState(() => _isEditing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error updating name: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Settings"),
        automaticallyImplyLeading: false,
        actions: [
            if (_isEditing)
              IconButton(onPressed: _updateName, icon: const Icon(Icons.check))
            else
              IconButton(onPressed: () => setState(() => _isEditing = true), icon: const Icon(Icons.edit)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profile Card
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : "?",
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isEditing)
                  TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(hintText: "Enter full name"),
                  )
                else
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 4),
                Text(widget.email, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Semester ${widget.semester} • Section ${widget.section}",
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 2. Settings Section
          const Text("APP SETTINGS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          
          Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Dark Mode"),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: isDarkMode,
                  onChanged: (bool value) async {
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('is_dark_mode', value);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Text("SUPPORT", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
           const SizedBox(height: 8),
           
           Card(
            elevation: 0,
             color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
            child: Column(
              children: [
                 ListTile(
                  leading: const Icon(Icons.assignment_late_outlined, color: Colors.orange),
                  title: const Text("Request Attendance Correction"),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RequestCorrectionPage(email: widget.email)));
                  },
                ),
              ]
            )
           ),

          const SizedBox(height: 24),
          
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.red.withOpacity(0.05),
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()), 
                  (route) => false
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
