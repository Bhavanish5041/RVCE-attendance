import 'package:flutter/material.dart';
import 'dart:io'; // Required for File
import 'package:image_picker/image_picker.dart'; // Required for Camera/Gallery
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Required for Bluetooth
import 'main.dart'; // Required to access the Dark Mode controller

class StudentScreen extends StatefulWidget {
  final String studentEmail;
  
  const StudentScreen({super.key, this.studentEmail = "student.ai23@rvce.edu.in"});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  int _currentIndex = 0;
  String _displayName = "Student";
  String _displayUSN = "Loading...";

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _parseStudentData();
    
    _pages = [
      DashboardPage(name: _displayName), // Index 0
      const TimetablePage(),             // Index 1
      SettingsPage(name: _displayName, email: widget.studentEmail), // Index 2
    ];
  }

  void _parseStudentData() {
    try {
      String localPart = widget.studentEmail.split('@')[0]; 
      String namePart = localPart.split('.')[0];
      
      _displayName = namePart[0].toUpperCase() + namePart.substring(1);
      
      String batchPart = localPart.split('.')[1].toUpperCase(); 
      _displayUSN = "1RV${batchPart}0${namePart.length + 40}"; 
    } catch (e) {
      _displayName = "Student";
      _displayUSN = "1RV23AI000";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
            // Re-initialize pages to update names if needed
            _pages[0] = DashboardPage(name: _displayName);
            _pages[2] = SettingsPage(name: _displayName, email: widget.studentEmail);
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Timetable'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ==========================================
// 1. DASHBOARD PAGE (Fixed & Secure)
// ==========================================
class DashboardPage extends StatelessWidget {
  final String name;
  const DashboardPage({super.key, required this.name});

  Future<void> _markAttendance(BuildContext context) async {
    // 1. Check if Bluetooth is On
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please turn on Bluetooth first!")),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Start Scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      String foundClassName = ""; 
      
      // 3. Listen to Scan Results (WITH SECURITY FILTER)
      var subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          String deviceName = r.device.platformName;
          
          // SECURITY CHECK: Only accept devices starting with "RVCE_CLASS"
          if (deviceName.startsWith("RVCE_CLASS")) {
             print("Valid Class Found: $deviceName");
             foundClassName = deviceName; 
          }
        }
      });

      // Wait for scan to finish
      await Future.delayed(const Duration(seconds: 4));
      
      // Stop scanning
      await FlutterBluePlus.stopScan();
      await subscription.cancel();
      
      if (context.mounted) Navigator.pop(context); // Close spinner

      // 4. Show Result based on what we found
      if (foundClassName.isNotEmpty) {
        String cleanName = foundClassName.replaceAll("RVCE_CLASS_", "");
        if (context.mounted) _showSuccessDialog(context, cleanName);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text("No Class Beacon Found. Ask teacher to start."),
               backgroundColor: Colors.red,
             ),
          );
        }
      }

    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      print("Error: $e");
    }
  }

  void _showSuccessDialog(BuildContext context, String className) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text("Attendance Marked!"),
        content: Text("You have successfully checked into:\n\n$className"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mock Data
    final List<Map<String, dynamic>> subjects = [
      {"name": "Artificial Intelligence", "code": "AI-301", "attended": 24, "total": 28},
      {"name": "Embedded Systems", "code": "EC-204", "attended": 12, "total": 20},
      {"name": "Linear Algebra", "code": "MA-102", "attended": 28, "total": 30},
      {"name": "Computer Networks", "code": "CS-202", "attended": 18, "total": 22},
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Welcome, $name", style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverallCard(context),
            const SizedBox(height: 25),
            Text("Your Subjects", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.85,
              ),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                return _buildSubjectCard(context, subjects[index]);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _markAttendance(context),
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
        label: const Text("Mark Attendance", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildOverallCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade800, Colors.purple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Overall Attendance", style: TextStyle(color: Colors.white70, fontSize: 14)),
              SizedBox(height: 5),
              Text("82.5%", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text("You are safe!", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(Icons.pie_chart, size: 80, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Map<String, dynamic> subject) {
    double percentage = subject['attended'] / subject['total'];
    int percentageInt = (percentage * 100).toInt();
    Color statusColor = percentageInt < 75 ? Colors.red : Colors.green;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: percentage,
                  backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  color: statusColor,
                  strokeWidth: 6,
                ),
              ),
              Text("$percentageInt%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          Column(
            children: [
              Text(subject['code'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 4),
              Text(subject['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          Text("${subject['attended']} / ${subject['total']} Classes", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }
}

// ==========================================
// 2. TIMETABLE PAGE
// ==========================================
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  File? _selectedImage;
  bool _isScanning = false;
  bool _hasData = false;

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _timeSlots = [
    {"time": "09:00 - 10:00", "subject": "AI & ML", "room": "CR-405", "teacher": "Dr. Kavita"},
    {"time": "10:00 - 11:00", "subject": "Embedded Sys", "room": "Lab-2", "teacher": "Prof. Rajesh"},
    {"time": "11:00 - 11:30", "subject": "BREAK", "room": "-", "teacher": "-"},
    {"time": "11:30 - 12:30", "subject": "Linear Algebra", "room": "CR-402", "teacher": "Dr. Meera"},
    {"time": "12:30 - 01:30", "subject": "Networks", "room": "CR-401", "teacher": "Prof. Anand"},
  ];

  Future<void> _pickAndScanImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);
      _isScanning = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isScanning = false;
      _hasData = true;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Timetable scanned successfully!")),
      );
    }
  }

  void _showDetails(Map<String, String> slot) {
    if (slot['subject'] == "BREAK") return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(slot['subject']!),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.access_time, "Time", slot['time']!),
            const SizedBox(height: 10),
            _detailRow(Icons.room, "Room", slot['room']!),
            const SizedBox(height: 10),
            _detailRow(Icons.person, "Teacher", slot['teacher']!),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Timetable"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _pickAndScanImage,
            tooltip: "Upload New Timetable",
          )
        ],
      ),
      body: !_hasData
          ? _buildUploadState() 
          : _buildTimetableState(),
    );
  }

  Widget _buildUploadState() {
    return Center(
      child: _isScanning
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Extracting text from image...", style: TextStyle(color: Colors.grey)),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 80, color: Colors.purple.shade200),
                const SizedBox(height: 20),
                const Text("No Timetable Found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("Upload a picture to generate one automatically", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _pickAndScanImage,
                  icon: const Icon(Icons.upload),
                  label: const Text("Upload Timetable Image"),
                ),
              ],
            ),
    );
  }

  Widget _buildTimetableState() {
    return Column(
      children: [
        if (_selectedImage != null)
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(_selectedImage!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
              ),
            ),
            child: Center(
              child: TextButton.icon(
                onPressed: _pickAndScanImage,
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text("Change Image", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _timeSlots.length,
            itemBuilder: (context, index) {
              final slot = _timeSlots[index];
              bool isBreak = slot['subject'] == "BREAK";

              return Card(
                elevation: isBreak ? 0 : 2,
                color: isBreak ? Colors.grey.shade200 : Theme.of(context).cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isBreak ? Colors.grey : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      slot['time']!.split(' - ')[0], 
                      style: TextStyle(fontWeight: FontWeight.bold, color: isBreak ? Colors.white : Colors.purple),
                    ),
                  ),
                  title: Text(slot['subject']!, style: TextStyle(fontWeight: FontWeight.bold, color: isBreak ? Colors.grey : null)),
                  subtitle: isBreak ? null : Text("Room: ${slot['room']} • ${slot['teacher']}"),
                  trailing: isBreak ? null : const Icon(Icons.info_outline, color: Colors.grey),
                  onTap: () => _showDetails(slot),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. SETTINGS PAGE
// ==========================================
class SettingsPage extends StatefulWidget {
  final String name;
  final String email;
  const SettingsPage({super.key, required this.name, required this.email});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    bool isDarkMode = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), automaticallyImplyLeading: false),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Text(widget.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
            ),
            title: Text(widget.name),
            subtitle: Text(widget.email),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Dark Mode"),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: isDarkMode,
            onChanged: (bool value) {
              setState(() {
                themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log Out", style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}