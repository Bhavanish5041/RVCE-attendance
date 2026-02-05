import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'; 
import 'attendance/scan_screen.dart';
import '../services/database_service.dart';
import 'login_screen.dart';
import 'request_correction_page.dart';

// ==========================================
// 1. MAIN STUDENT SCREEN (NAVIGATION)
// ==========================================
class StudentScreen extends StatefulWidget {
  final String studentEmail;
  const StudentScreen({super.key, this.studentEmail = "student.ai24@rvce.edu.in"});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  int _currentIndex = 0;
  String _displayName = "Student";
  
  List<Widget> _pages = [
    const Center(child: CircularProgressIndicator()),
    const Center(child: CircularProgressIndicator()),
    const Center(child: CircularProgressIndicator()),
    const Center(child: CircularProgressIndicator()),
    const Center(child: CircularProgressIndicator()),
  ];

  @override
  void initState() {
    super.initState();
    _parseStudentData();
    _initSequence(); 
  }

  Future<void> _initSequence() async {
    // Get email from authenticated user if available, otherwise use passed email
    final authUser = Supabase.instance.client.auth.currentUser;
    final email = authUser?.email ?? widget.studentEmail;
    
    // Try to register, but ignore errors for demo/offline logic
    await DatabaseService().registerStudent(email); 
    await _requestPermissions();
    
    if (mounted) {
      setState(() {
        _pages = [
          DashboardPage(name: _displayName, email: email),
          AttendanceDashboardPage(email: email),
          MaterialsPage(email: email),
          TimetablePage(email: email), 
          SettingsPage(name: _displayName, email: email), 
        ];
      });
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location, Permission.notification].request();
  }

  void _parseStudentData() {
    try {
      String localPart = widget.studentEmail.split('@')[0]; 
      String namePart = localPart.split('.')[0];
      _displayName = namePart[0].toUpperCase() + namePart.substring(1);
    } catch (e) {
      _displayName = "Student";
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
            if (_pages.length == 5 && _pages[0] is! Center) {
               _pages = [
                DashboardPage(name: _displayName, email: widget.studentEmail),
                AttendanceDashboardPage(email: widget.studentEmail),
                MaterialsPage(email: widget.studentEmail),
                TimetablePage(email: widget.studentEmail),
                SettingsPage(name: _displayName, email: widget.studentEmail),
              ];
            }
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Materials'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Timetable'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ==========================================
// 2. DASHBOARD PAGE (ANALYTICS + BUTTON)
// ==========================================
// ==========================================
// 2. DASHBOARD PAGE (Refactored to Figma Design)
// ==========================================
class DashboardPage extends StatefulWidget {
  final String name;
  final String email; 
  const DashboardPage({super.key, required this.name, required this.email});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedTab = 0; // 0: Home, 1: News, 2: Events
  String _selectedSubject = 'DSA';
  String _section = ''; // Student's semester/section

  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = DatabaseService().fetchFullAnalytics(widget.email);
    _loadSection();
  }

  void _loadSection() async {
    final section = await DatabaseService().getStudentSection(widget.email);
    if (mounted) {
      setState(() => _section = section);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark, textColor),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _analyticsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  
                  final data = snapshot.data ?? {};
                  final subjects = data['subjects'] as List? ?? [];
                  
                  // Extract subject names for the dropdown
                  final List<String> subjectNames = subjects
                      .map((s) => s['name']?.toString() ?? "Unknown Subject")
                      .toSet() // Remove duplicates
                      .toList();
                  
                  // Ensure _selectedSubject is valid or default to first
                  // Note: best handled in state but for immediate UI sync this works
                  if (subjectNames.isNotEmpty && !subjectNames.contains(_selectedSubject)) {
                    // Safe logic to avoid setstate during build
                     _selectedSubject = subjectNames.first;
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                       const SizedBox(height: 20),
                       _buildTabSelector(isDark, textColor),
                       const SizedBox(height: 20),
                       
                       if (_selectedTab == 0) ...[
                         // Today's classes and attendance card only
                         _buildTodayClassesSection(isDark, cardColor),
                         const SizedBox(height: 30),
                         // Pass the valid dropdown list
                         _buildAttendanceCard(subjectNames, isDark, cardColor),
                       ] else ...[
                         const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("News & Events Feed coming soon!")))
                       ],

                       const SizedBox(height: 30),
                       // Example News Card from Figma
                       _buildNewsCard(isDark, cardColor),
                       const SizedBox(height: 80), // Bottom padding
                      ],
                    ),
                  );
                }
              ),
            ),
          ],
        ),
      ),
      /* 
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ScanScreen(subjectName: "Current Class"),
            ),
          );
        }, 
        backgroundColor: const Color(0xFF8B2072), 
        icon: const Icon(Icons.bluetooth_searching, color: Colors.white), 
        label: const Text("Mark Attendance", style: TextStyle(color: Colors.white))
      ),
      */
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showProfileSheet(isDark),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.shade50,
                  radius: 20,
                  child: Text(widget.name.isNotEmpty ? widget.name[0] : "S", style: const TextStyle(color: Color(0xFF8B2072), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Hi, ${widget.name}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(_section.isNotEmpty ? _section : "Loading...", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: textColor),
            onPressed: () => _showNotificationsSheet(isDark),
          )
        ],
      ),
    );
  }

  void _showProfileSheet(bool isDark) {
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Profile Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF8B2072),
                      radius: 40,
                      child: Text(
                        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : "S",
                        style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.name,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B2072).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _section.isNotEmpty ? _section : "Section not set",
                        style: const TextStyle(color: Color(0xFF8B2072), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Details Section
              _buildProfileDetailRow(Icons.email_outlined, "Email", widget.email, isDark),
              _buildProfileDetailRow(Icons.school_outlined, "Section", _section.isNotEmpty ? _section : "Not set", isDark),
              
              const SizedBox(height: 24),
              
              // Teachers Section
              Text(
                "My Teachers",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 12),
              
              // Fetch and display teachers
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getStudentTeachers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text("No teachers found", style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final teacher = snapshot.data![index];
                        return _buildTeacherTile(teacher, isDark, cardColor);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF8B2072), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherTile(Map<String, dynamic> teacher, bool isDark, Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            radius: 22,
            child: Text(
              (teacher['professor'] ?? teacher['name'] ?? 'T')[0].toUpperCase(),
              style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacher['professor'] ?? teacher['name'] ?? 'Unknown Teacher',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  teacher['subject_code'] ?? 'Subject not specified',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B2072).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              teacher['room_number'] ?? 'TBA',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B2072), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getStudentTeachers() async {
    if (_section.isEmpty) return [];
    
    try {
      // Get all timetable entries for this section (which includes classes student added)
      final timetable = await Supabase.instance.client
          .from('timetable')
          .select('professor, subject_code, room_number')
          .eq('section', _section);
      
      // Group by professor and collect all their subjects
      final Map<String, Map<String, dynamic>> teacherMap = {};
      
      for (var entry in timetable) {
        final prof = entry['professor']?.toString() ?? '';
        if (prof.isEmpty) continue;
        
        if (!teacherMap.containsKey(prof)) {
          teacherMap[prof] = {
            'professor': prof,
            'subjects': <String>[],
            'room_number': entry['room_number'] ?? 'TBA',
          };
        }
        
        // Add subject if not already in list
        final subject = entry['subject_code']?.toString() ?? '';
        if (subject.isNotEmpty) {
          final subjects = teacherMap[prof]!['subjects'] as List<String>;
          if (!subjects.contains(subject)) {
            subjects.add(subject);
          }
        }
      }
      
      // Convert subjects list to comma-separated string
      return teacherMap.values.map((teacher) {
        final subjects = teacher['subjects'] as List<String>;
        return {
          'professor': teacher['professor'],
          'subject_code': subjects.join(', '),
          'room_number': teacher['room_number'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  void _showNotificationsSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: DatabaseService().fetchDashboardAlerts(widget.email),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final cancellations = (snapshot.data?['cancellations'] as List?) ?? [];
                    final attendanceAlerts = (snapshot.data?['attendance'] as List?) ?? [];
                    
                    if (cancellations.isEmpty && attendanceAlerts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              "No notifications",
                              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "You're all caught up! 🎉",
                              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView(
                      controller: scrollController,
                      children: [
                        // Class Cancellations
                        ...cancellations.map((c) => _buildNotificationTile(
                          icon: Icons.cancel_outlined,
                          iconColor: Colors.red,
                          title: "Class Cancelled",
                          subtitle: "${c['subject'] ?? 'Unknown'} on ${c['date'] ?? 'TBD'}",
                          time: c['created_at']?.toString().substring(0, 10) ?? '',
                          isDark: isDark,
                        )),
                        // Attendance Alerts
                        ...attendanceAlerts.map((a) {
                          final pct = (a['percentage'] as num?)?.toInt() ?? 0;
                          final isLow = pct < 75;
                          return _buildNotificationTile(
                            icon: isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            iconColor: isLow ? Colors.orange : Colors.green,
                            title: isLow ? "Low Attendance Warning" : "Good Attendance",
                            subtitle: "${a['name'] ?? 'Subject'}: $pct%",
                            time: "",
                            isDark: isDark,
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          if (time.isNotEmpty)
            Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildTabSelector(bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : const Color(0xFFF4F3FF),
        borderRadius: BorderRadius.circular(16)
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           _buildTabItem("Home", 0, isDark, textColor),
           _buildTabItem("News", 1, isDark, textColor),
           _buildTabItem("Events", 2, isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildTabItem(String text, int index, bool isDark, Color textColor) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.grey[700] : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0,2))] : []
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? textColor : const Color(0xFF939393),
            fontWeight: FontWeight.w600,
            fontSize: 14
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSection(List<dynamic> subjects) {
    if (subjects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text("No subjects found."),
      );
    }

    return SizedBox(
      height: 105, // Updated Height to match Figma
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subject = subjects[index];
          final pct = (subject['percentage'] as num?)?.toInt() ?? 0;
          
          // Color based on attendance percentage
          final gradientColors = pct >= 75 
              ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)] // Green
              : pct >= 60 
                  ? [const Color(0xFFFF9800), const Color(0xFFEF6C00)] // Orange
                  : [const Color(0xFFF44336), const Color(0xFFB71C1C)]; // Red
          
          return Container(
            width: 87, // Figma Width
            margin: const EdgeInsets.only(right: 12), // Spacing
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  width: 3, 
                  color: Color(0xFF8B2072) // Figma Purple Border
                ),
                borderRadius: BorderRadius.circular(8), // Figma Radius
              ),
            ),
            child: Stack(
              children: [
                // Optional: Gradient to make white text readable on light images
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5), // Inner radius
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)]
                    )
                  ),
                ),
                // Subject Name at Bottom Left
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8, right: 4),
                    child: Text(
                      subject['name'] ?? "Unknown",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10, // Figma had 8, bumping slightly for readability
                        // fontFamily: 'Poppins', // Inherited from Theme
                        fontWeight: FontWeight.w500,
                        height: 1.13,
                      ),
                    ),
                  ),
                ),
                // Percentage Badge (Top Right) - Kept for functionality
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: const Color(0xFF8B2072).withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      "${(subject['percentage'] as num).toInt()}%",
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayClassesSection(bool isDark, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Classes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                   // Switch to Timetable tab
                   final _StudentScreenState? parent = context.findAncestorStateOfType<_StudentScreenState>();
                   if (parent != null) {
                     parent.setState(() {
                       parent._currentIndex = 3; // Switch to Timetable
                     });
                   }
                }, 
                child: const Text("Open schedule", style: TextStyle(color: Color(0xFF8B2072), fontWeight: FontWeight.w600)),
              )
            ],
          ),
          const SizedBox(height: 12),
          
          FutureBuilder<String>(
            future: DatabaseService().getStudentSection(widget.email),
            builder: (context, sectionSnap) {
              if (!sectionSnap.hasData) return const Center(child: CircularProgressIndicator());
              final section = sectionSnap.data!;
              final today = DateTime.now().weekday;

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('timetable')
                    .stream(primaryKey: ['id'])
                    .eq('section', section)
                    .order('start_time', ascending: true),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                     return _buildEmptyState("No classes found.", isDark);
                  }

                  final allData = snapshot.data!;
                  final todayClasses = allData.where((c) => c['day_of_week'] == today).toList();

                  if (todayClasses.isEmpty) {
                    return _buildEmptyState("No classes scheduled for today! 🎉", isDark);
                  }

                  return Column(
                    children: todayClasses.map((c) {
                      int h = int.parse(c['start_time'].toString().split(':')[0]);
                      // Simple Time formatting
                      String startTime = "${h > 12 ? h - 12 : h}:00 ${h >= 12 ? 'PM' : 'AM'}";
                      int endH = h + 1; // Assuming 1 hour duration for simplicity if not stored
                      String endTime = "${endH > 12 ? endH - 12 : endH}:00 ${endH >= 12 ? 'PM' : 'AM'}";

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildClassCard(
                          title: c['subject_code'] ?? 'Unknown Subject',
                          time: "$startTime - $endTime",
                          subtitle: "${c['professor'] ?? 'Staff'} • ${c['room_number'] ?? 'TBA'}",
                          color: cardColor,
                          isDark: isDark,
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(List<String> availableSubjects, bool isDark, Color cardColor) {
     // Fallback if list is empty
    final displaySubjects = availableSubjects.isNotEmpty ? availableSubjects : ['No Subjects'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Select Subject to Mark Attendance", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // Subject Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: (displaySubjects.contains(_selectedSubject)) ? _selectedSubject : displaySubjects.first,
                  isExpanded: true,
                  items: displaySubjects.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue == null || newValue == 'No Subjects') return;
                    setState(() {
                      _selectedSubject = newValue;
                    });
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // The "Scan" Button
            ElevatedButton.icon(
              icon: const Icon(Icons.radar, color: Colors.white),
              label: const Text("SCAN FOR CLASS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B), // Gold Color
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Navigate to the Scanning Animation Screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScanScreen(subjectName: _selectedSubject),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : const Color(0xFFF4F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCACACA)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF939393), fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildClassCard({required String title, required String time, required String subtitle, required Color color, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCACACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(color: const Color(0xFF8B2072), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(color: Color(0xFF939393), fontSize: 12)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Color(0xFF939393), fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNewsCard(bool isDark, Color cardColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFFCACACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: isDark ? Colors.purple.withValues(alpha: 0.2) : const Color(0xFFECEBF8), borderRadius: BorderRadius.circular(20)),
                child: const Text("May 01", style: TextStyle(color: Color(0xFF8B2072), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "The Federal Board of Intermediate and Secondary Education (FBISE) has officially announced...",
            style: TextStyle(fontSize: 12, color: Color(0xFF939393)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. ATTENDANCE DASHBOARD PAGE
// ==========================================
class AttendanceDashboardPage extends StatefulWidget {
  final String email;
  const AttendanceDashboardPage({super.key, required this.email});

  @override
  State<AttendanceDashboardPage> createState() => _AttendanceDashboardPageState();
}

class _AttendanceDashboardPageState extends State<AttendanceDashboardPage> {
  late Future<Map<String, dynamic>> _analyticsFuture;
  String _section = '';

  @override
  void initState() {
    super.initState();
    _analyticsFuture = DatabaseService().fetchFullAnalytics(widget.email);
    _loadSection();
  }

  void _loadSection() async {
    final section = await DatabaseService().getStudentSection(widget.email);
    if (mounted) setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("My Attendance"),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Could not load attendance data", style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _analyticsFuture = DatabaseService().fetchFullAnalytics(widget.email);
                    }),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          // Safely convert List<dynamic> to List<Map<String, dynamic>>
          final rawSubjects = data['subjects'] as List<dynamic>? ?? [];
          final subjects = rawSubjects.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          
          // Calculate overall stats from subjects
          int totalClasses = 0;
          int totalPresent = 0;
          for (var s in subjects) {
            totalClasses += (s['total_classes'] as num?)?.toInt() ?? 0;
            totalPresent += (s['attended'] as num?)?.toInt() ?? 0;
          }
          final overallPercentage = totalClasses > 0 ? ((totalPresent / totalClasses) * 100).round() : 0;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _analyticsFuture = DatabaseService().fetchFullAnalytics(widget.email);
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Attendance Card
                  _buildOverallCard(overallPercentage, totalPresent, totalClasses, isDark, cardColor, textColor),
                  const SizedBox(height: 24),
                  
                  // Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Subject-wise Attendance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      Text("${subjects.length} subjects", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Subject Cards
                  if (subjects.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text("No subjects found", style: TextStyle(color: Colors.grey[500])),
                            const SizedBox(height: 8),
                            Text("Add classes to your timetable first", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...subjects.map((subject) => _buildSubjectCard(subject, isDark, cardColor, textColor)),
                  
                  const SizedBox(height: 24),
                  
                  // Attendance Legend
                  _buildLegend(isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverallCard(int percentage, int present, int total, bool isDark, Color cardColor, Color textColor) {
    final color = _getAttendanceColor(percentage);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF8B2072), const Color(0xFFB34D9B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B2072).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular Progress
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: percentage / 100,
                        strokeWidth: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$percentage%",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Text("Overall", style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Overall Attendance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatPill("Present", present.toString(), Colors.green.shade300),
                        const SizedBox(width: 10),
                        _buildStatPill("Total", total.toString(), Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: percentage >= 75 ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        percentage >= 75 ? "✓ Above 75% - Good!" : "⚠ Below 75% - Improve",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, bool isDark, Color cardColor, Color textColor) {
    final name = subject['name']?.toString() ?? 'Unknown';
    final percentage = (subject['percentage'] as num?)?.toInt() ?? 0;
    final present = (subject['attended'] as num?)?.toInt() ?? 0;
    final total = (subject['total_classes'] as num?)?.toInt() ?? 0;
    final color = _getAttendanceColor(percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$percentage%",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$present / $total classes", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text(
                _getStatusText(percentage),
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800]!.withValues(alpha: 0.5) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Attendance Legend", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.green, "≥ 75%", "Safe"),
              _buildLegendItem(Colors.orange, "60-74%", "Warning"),
              _buildLegendItem(Colors.red, "< 60%", "Critical"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String range, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(range, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Color _getAttendanceColor(int percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getStatusText(int percentage) {
    if (percentage >= 75) return "On Track";
    if (percentage >= 60) return "Needs Improvement";
    return "Critical - Attend More!";
  }
}

// ==========================================
// 4. MATERIALS PAGE
// ==========================================
class MaterialsPage extends StatefulWidget {
  final String email;
  const MaterialsPage({super.key, required this.email});
  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'PDF', 'Video', 'Link'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Study Materials"),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = filter);
                    },
                    selectedColor: const Color(0xFF8B2072),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    checkmarkColor: Colors.white,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Materials List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService().streamStudentMaterials(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "No materials yet",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Materials shared by your teachers\nwill appear here",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                var materials = snapshot.data!;
                
                // Apply filter
                if (_selectedFilter != 'All') {
                  materials = materials.where((m) => 
                    (m['resource_type']?.toString().toUpperCase() ?? '') == _selectedFilter.toUpperCase()
                  ).toList();
                }

                if (materials.isEmpty) {
                  return Center(
                    child: Text(
                      "No $_selectedFilter materials found",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: materials.length,
                  itemBuilder: (context, index) {
                    final material = materials[index];
                    return _buildMaterialCard(material, isDark, cardColor, textColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material, bool isDark, Color cardColor, Color textColor) {
    final type = material['resource_type']?.toString() ?? 'PDF';
    final IconData icon;
    final Color iconColor;
    
    switch (type.toUpperCase()) {
      case 'VIDEO':
        icon = Icons.play_circle_filled;
        iconColor = Colors.red;
        break;
      case 'LINK':
        icon = Icons.link;
        iconColor = Colors.blue;
        break;
      case 'PDF':
      default:
        icon = Icons.picture_as_pdf;
        iconColor = Colors.orange;
    }

    // Format date
    String dateStr = '';
    if (material['created_at'] != null) {
      try {
        final date = DateTime.parse(material['created_at'].toString());
        final now = DateTime.now();
        final diff = now.difference(date);
        if (diff.inDays == 0) {
          dateStr = 'Today';
        } else if (diff.inDays == 1) {
          dateStr = 'Yesterday';
        } else if (diff.inDays < 7) {
          dateStr = '${diff.inDays} days ago';
        } else {
          dateStr = '${date.day}/${date.month}/${date.year}';
        }
      } catch (e) {
        dateStr = '';
      }
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openMaterial(material),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material['title'] ?? 'Untitled',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B2072).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            material['subject_code'] ?? 'General',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8B2072), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _openMaterial(Map<String, dynamic> material) async {
    final url = material['file_url']?.toString();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No file URL available"), backgroundColor: Colors.red),
      );
      return;
    }
    
    // Show a dialog with options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(material['title'] ?? 'Material'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Subject: ${material['subject_code'] ?? 'Unknown'}"),
            const SizedBox(height: 8),
            Text("Type: ${material['resource_type'] ?? 'PDF'}"),
            const SizedBox(height: 16),
            const Text(
              "Tap 'Open/Download' to view the file",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final uri = Uri.parse(url);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error opening file: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text("Open/Download"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B2072),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. TIMETABLE PAGE
// ==========================================
class TimetablePage extends StatefulWidget {
  final String email;
  const TimetablePage({super.key, required this.email});
  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  int _selectedDay = 1; 
  String _getDayName(int day) => ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][day - 1];
  String? _section;

  @override
  void initState() {
    super.initState();
    _loadSection();
  }

  void _loadSection() async {
    final s = await DatabaseService().getStudentSection(widget.email);
    if (mounted) setState(() => _section = s);
  }

  void _showAddDialog(BuildContext context) {
    // [Keeping dialog logic same]
    final subjectCtrl = TextEditingController();
    final profCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    int selectedTime = 9; 

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(title: Text("Add Class for ${_getDayName(_selectedDay)}"), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: "Subject Name", icon: Icon(Icons.book))), TextField(controller: profCtrl, decoration: const InputDecoration(labelText: "Professor", icon: Icon(Icons.person))), TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: "Room", icon: Icon(Icons.room))), const SizedBox(height: 20), Row(children: [const Icon(Icons.access_time, color: Colors.grey), const SizedBox(width: 15), const Text("Time: "), DropdownButton<int>(value: selectedTime, items: List.generate(9, (index) { int hour = 9 + index; return DropdownMenuItem(value: hour, child: Text("${hour > 12 ? hour - 12 : hour}:00 ${hour >= 12 ? 'PM' : 'AM'}")); }), onChanged: (val) => setDialogState(() => selectedTime = val!))])])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")), ElevatedButton(onPressed: () async { 
            if (subjectCtrl.text.isNotEmpty) { 
              try {
                // Use safe manual add method
                await DatabaseService().addStudentClass(
                  subject: subjectCtrl.text,
                  professor: profCtrl.text,
                  room: roomCtrl.text,
                  day: _selectedDay.toString(),
                  time: selectedTime.toString(),
                  section: _section ?? 'Unknown',
                ); 
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Class added successfully!"), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error adding class: $e"), backgroundColor: Colors.red));
                }
              }
            } 
          }, child: const Text("Add"))]);
      }));
  }

  void _deleteEntry(dynamic id) {
    DatabaseService().deleteTimetableEntry(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Class deleted")));
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Dark Mode Check
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: const Text("My Timetable"), automaticallyImplyLeading: false, elevation: 0),
      body: Column(children: [
          Container(
            height: 60, 
            color: isDark ? Colors.grey[900] : Colors.white, // 🟢 Fix
            child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 6, itemBuilder: (context, index) { 
              int day = index + 1; 
              bool isSelected = day == _selectedDay; 
              return GestureDetector(onTap: () => setState(() => _selectedDay = day), child: Container(
                width: 70, 
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5), 
                decoration: BoxDecoration(color: isSelected ? Colors.purple : (isDark ? Colors.grey[800] : Colors.grey.shade100), borderRadius: BorderRadius.circular(20)), 
                alignment: Alignment.center, 
                child: Text(_getDayName(day), style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold)))); 
            })
          ),
          const Divider(height: 1),
          Expanded(child: _buildDaySchedule(isDark, cardColor, textColor)),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddDialog(context), backgroundColor: Colors.purple, child: const Icon(Icons.add, color: Colors.white)),
    );
  }

  Widget _buildDaySchedule(bool isDark, Color cardColor, Color? textColor) {
    if (_section == null) return const Center(child: CircularProgressIndicator());
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('timetable').stream(primaryKey: ['id']).eq('section', _section!).order('start_time', ascending: true), 
      builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final allClasses = snapshot.data!;
            final classes = allClasses.where((c) {
              final dayValue = c['day_of_week'];
              final dayInt = dayValue is int ? dayValue : int.tryParse(dayValue.toString()) ?? 0;
              return dayInt == _selectedDay;
            }).toList();
            if (classes.isEmpty) return const Center(child: Text("No classes today. Tap + to add."));
            return ListView.builder(padding: const EdgeInsets.all(16), itemCount: classes.length, itemBuilder: (context, index) { final item = classes[index]; int h = int.parse(item['start_time'].toString().split(':')[0]); String time = "${h > 12 ? h - 12 : h}:00 ${h >= 12 ? 'PM' : 'AM'}"; return Dismissible(key: Key(item['id'].toString()), direction: DismissDirection.endToStart, background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)), onDismissed: (_) => _deleteEntry(item['id']), child: Card(color: cardColor, elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple.shade50, borderRadius: BorderRadius.circular(8)), child: Text(time.split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))), title: Text(item['subject_code'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${item['professor'] ?? 'Staff'} • ${item['room_number']}")))); });
      }
    );
  }
}

// ==========================================
// 4. PRIORITY NOTIFICATIONS
// ==========================================
class PriorityNotifications extends StatefulWidget {
  final String userEmail;
  const PriorityNotifications({super.key, required this.userEmail});
  @override
  State<PriorityNotifications> createState() => _PriorityNotificationsState();
}

class _PriorityNotificationsState extends State<PriorityNotifications> {
  Map<String, dynamic>? _upcomingClass;
  Future<Map<String, dynamic>>? _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = DatabaseService().fetchDashboardAlerts(widget.userEmail);
    _loadUpcomingClass();
  }

  void _loadUpcomingClass() async {
    final classData = await DatabaseService().getUpcomingClass(widget.userEmail);
    if (mounted) setState(() => _upcomingClass = classData);
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Dark Mode Check
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Priority Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)), const SizedBox(height: 10),
        _upcomingClass != null ? _buildUpcomingClassCard(_upcomingClass!, isDark) : _buildNoClassCard(isDark),
        FutureBuilder<Map<String, dynamic>>(future: _alertsFuture, builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final cancellations = snapshot.data!['cancellations'] as List;
            final attendance = snapshot.data!['attendance'] as List;
            return Column(children: [...cancellations.map((c) => _buildCancelCard(c, isDark)), ...attendance.map((a) => _buildAttendanceCard(a, isDark))]);
        }),
    ]);
  }

  Widget _buildUpcomingClassCard(Map<String, dynamic> classData, bool isDark) {
    int hour = int.parse(classData['start_time'].toString().split(':')[0]);
    String timeString = "${hour > 12 ? hour - 12 : hour}:00 ${hour >= 12 ? 'PM' : 'AM'}";
    return Container(
      margin: const EdgeInsets.only(bottom: 10), 
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(
        // 🟢 Dark mode friendly tint
        color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50, 
        border: Border(left: BorderSide(color: Colors.blue.shade800, width: 4)), 
        borderRadius: BorderRadius.circular(8)
      ), 
      child: Row(children: [
        const Icon(Icons.access_time_filled, color: Colors.blue), 
        const SizedBox(width: 15), 
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("UPCOMING: ${classData['subject_code']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blue.shade100 : Colors.black)), 
          Text("${classData['professor']} • ${classData['room_number']}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)), 
          Text("Starts at $timeString", style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold))
        ]))
      ])
    );
  }

  Widget _buildNoClassCard(bool isDark) {
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)), child: const Row(children: [Icon(Icons.bedtime, color: Colors.green), SizedBox(width: 15), Text("No more classes today! 🎉", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]));
  }

  Widget _buildCancelCard(Map data, bool isDark) {
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300)), child: Row(children: [const Icon(Icons.event_busy, color: Colors.grey), const SizedBox(width: 15), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("CANCELED: ${data['class_name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), Text(data['reason'] ?? "No reason", style: const TextStyle(fontSize: 12))])]));
  }

  Widget _buildAttendanceCard(Map data, bool isDark) {
    bool isCritical = data['status'] == 'CRITICAL';
    Color color = isCritical ? Colors.red : Colors.orange;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), border: Border(left: BorderSide(color: color, width: 4)), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(isCritical ? Icons.warning_amber : Icons.info_outline, color: color), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${data['subject']}: ${data['percentage'].toStringAsFixed(1)}%", style: TextStyle(fontWeight: FontWeight.bold, color: color)), Text(isCritical ? "Attend next ${data['needed']} classes!" : "Careful, you're on the edge.", style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))]))]));
  }
}

// ==========================================
// 5. SETTINGS PAGE
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
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), automaticallyImplyLeading: false),
      body: ListView(children: [
        const SizedBox(height: 20),
        ListTile(leading: CircleAvatar(backgroundColor: Colors.purple.shade100, child: Text(widget.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))), title: Text(widget.name), subtitle: Text(widget.email)),
        const Divider(),
        SwitchListTile(title: const Text("Dark Mode"), secondary: const Icon(Icons.dark_mode_outlined), value: isDarkMode, onChanged: (bool value) { setState(() { themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light; }); }),
        const Divider(),
        // [NEW] Correction Request Tile
        ListTile(
          leading: const Icon(Icons.assignment_late_outlined, color: Colors.orange),
          title: const Text("Request Attendance Correction"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => RequestCorrectionPage(email: widget.email)));
          },
        ),
        const Divider(),
        ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Log Out", style: TextStyle(color: Colors.red)), onTap: () async {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
           Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        }
      })]),
    );
  }
}

// Note: RequestCorrectionPage is now imported from request_correction_page.dart