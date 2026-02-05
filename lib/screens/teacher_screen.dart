import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data'; // Uncomment for Real BLE
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart'; // Uncomment for Real BLE

// 🟢 IMPORTANT: Import LoginScreen for logout navigation
import 'login_screen.dart'; 
import '../services/database_service.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  int _currentIndex = 0;

  // 🟢 SHARED STATE
  String _profName = "";
  String _subject = "";
  String _department = "AIML";
  String _section = "A";
  int _year = 1;
  bool _isAdvertising = false;
  
  // 🌑 DARK MODE
  bool? _isDarkMode; 
  
  // 📧 CURRENT USER
  User? _currentUser;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _checkUserAndLoad();
  }

  // 🔒 1. SECURITY CHECK & LOAD
  Future<void> _checkUserAndLoad() async {
    // 1. Load Theme FIRST (Critical for Guest Mode to show UI)
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bool systemDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      _isDarkMode = prefs.getBool('is_dark_mode') ?? systemDark;
    });

    _currentUser = Supabase.instance.client.auth.currentUser;
    
    if (_currentUser == null) {
      // DEMO / OFFLINE MODE
      setState(() {
        _profName = "Demo Professor";
        _subject = "Demo Subject";
        _isLoadingProfile = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Running in Demo Mode (Offline)"), backgroundColor: Colors.orange)
        );
      }
      return;
    }

    // Load Profile
    await _loadProfileFromDB();
  }

  // 💾 2. FETCH PROFILE
  Future<void> _loadProfileFromDB() async {
    try {
      // First try teachers table
      final teacherData = await Supabase.instance.client
          .from('teachers')
          .select()
          .eq('user_id', _currentUser!.id)
          .maybeSingle();

      if (teacherData != null) {
        // Get teacher's assigned section/semester from timetable with subject name
        final timetableData = await Supabase.instance.client
            .from('timetable')
            .select('section, semester, subject_code, subjects(name, department)')
            .eq('teacher_id', _currentUser!.id)
            .limit(1)
            .maybeSingle();
        
        int semester = timetableData?['semester'] ?? 5;
        int year = ((semester - 1) ~/ 2) + 1; // Sem 5,6 = Year 3
        
        // Get subject details
        final subjectInfo = timetableData?['subjects'] as Map<String, dynamic>?;
        
        setState(() {
          _profName = teacherData['name'] ?? 'Teacher';
          _subject = subjectInfo?['name'] ?? timetableData?['subject_code'] ?? '';
          _department = subjectInfo?['department'] ?? 'AIML';
          _section = timetableData?['section'] ?? 'A';
          _year = year;
          _isLoadingProfile = false;
        });
      } else {
        // Fallback to profiles table
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', _currentUser!.id)
            .maybeSingle();
        
        if (profileData != null) {
          setState(() {
            _profName = profileData['full_name'] ?? 'Teacher';
            _isLoadingProfile = false;
          });
        } else {
          setState(() => _isLoadingProfile = false);
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _showSetupDialog(context);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      setState(() => _isLoadingProfile = false);
    }
  }

  // 💾 3. SAVE PROFILE
  Future<void> _saveProfileToDB(String name, String subject, String section, int year) async {
    if (_currentUser == null || _currentUser!.email == null) return;

    try {
      await Supabase.instance.client.from('teacher_profiles').upsert({
        'email': _currentUser!.email!, 
        'name': name,
        'default_subject': subject,
        'default_section': section,
        'default_year': year,
      }, onConflict: 'email'); 

      setState(() {
        _profName = name;
        _subject = subject;
        _section = section;
        _year = year;
      });
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Saved!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _updateClassState(bool isAdvertising, String subject, String section, int year) {
    setState(() {
      _isAdvertising = isAdvertising;
      _subject = subject;
      _section = section;
      _year = year;
    });
  }

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    setState(() => _isDarkMode = value);
  }

  void _showSetupDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: _profName);
    final subCtrl = TextEditingController(text: _subject);
    String tempSection = _section;
    int tempYear = _year;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text("Teacher Setup"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Professor Name", icon: Icon(Icons.person))),
                TextField(controller: subCtrl, decoration: const InputDecoration(labelText: "Default Subject", icon: Icon(Icons.book))),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: tempYear,
                        isExpanded: true,
                        onChanged: (v) => setModalState(() => tempYear = v!),
                        items: [1,2,3,4].map((e) => DropdownMenuItem(value: e, child: Text("Year $e"))).toList(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        value: tempSection,
                        isExpanded: true,
                        onChanged: (v) => setModalState(() => tempSection = v!),
                        items: ['Section-A', 'Section-B', 'Section-C'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      ),
                    ),
                  ],
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty && subCtrl.text.isNotEmpty) {
                    await _saveProfileToDB(nameCtrl.text, subCtrl.text, tempSection, tempYear);
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("SAVE & CONTINUE"),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDarkMode == null || _isLoadingProfile) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.purple,
      scaffoldBackgroundColor: Colors.grey.shade50,
      cardColor: Colors.white,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.light),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.purple,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
    );

    return Theme(
      data: _isDarkMode! ? darkTheme : lightTheme,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            TeacherHomeView(
              profName: _profName,
              currentSubject: _subject,
              currentDepartment: _department,
              currentSection: _section,
              currentYear: _year,
              isAdvertising: _isAdvertising,
              onClassStateChanged: _updateClassState,
            ),
            TeacherTimetableView(profName: _profName),
            const TeacherTopicsView(),
            const TeacherRequestsView(), // NEW: Requests tab
            TeacherSettingsView(
              isDarkMode: _isDarkMode!, 
              onThemeChanged: _toggleTheme,
              profName: _profName,
              onEditProfile: () => _showSetupDialog(context),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: _isDarkMode! ? const Color(0xFF1E1E1E) : Colors.white,
          indicatorColor: _isDarkMode! ? Colors.purple.shade700 : Colors.purple.shade100,
          elevation: 10,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Timetable'),
            NavigationDestination(icon: Icon(Icons.add_box_outlined), selectedIcon: Icon(Icons.add_box), label: 'Topics'),
            NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Requests'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🏠 TAB 1: TEACHER DASHBOARD
// ============================================================================
class TeacherHomeView extends StatefulWidget {
  final String profName;
  final String currentSubject;
  final String currentDepartment;
  final String currentSection;
  final int currentYear;
  final bool isAdvertising;
  final Function(bool, String, String, int) onClassStateChanged;

  const TeacherHomeView({
    super.key,
    required this.profName,
    required this.currentSubject,
    required this.currentDepartment,
    required this.currentSection,
    required this.currentYear,
    required this.isAdvertising,
    required this.onClassStateChanged,
  });

  @override
  State<TeacherHomeView> createState() => _TeacherHomeViewState();
}

class _TeacherHomeViewState extends State<TeacherHomeView> {
  final List<Map<String, dynamic>> _attendanceList = [];
  List<Map<String, dynamic>> _upcomingClasses = [];
  RealtimeChannel? _subscription;
  
  // 🔽 MANUAL CLASS STATE
  List<String> _departments = [];
  List<int> _semesters = [];
  List<String> _sections = [];
  List<Map<String, dynamic>> _allSubjects = [];
  
  String? _selectedDept;
  int? _selectedSem;
  String? _selectedSection;
  String? _selectedSubjectCode;
  String? _selectedSubjectName;

  final TextEditingController _topicNameCtrl = TextEditingController();
  final TextEditingController _topicSummaryCtrl = TextEditingController();
  final TextEditingController _youtubeLinkCtrl = TextEditingController();
  final List<Map<String, dynamic>> _attachedFiles = [];

  @override
  void initState() {
    super.initState();
    if (widget.profName.isNotEmpty) _fetchSchedule();
    if (widget.isAdvertising) _startListeningToDatabase();
    _initDropdowns();
  }
  
  void _initDropdowns() async {
    final db = DatabaseService();
    // Load independent dropdowns
    final depts = await db.getDepartments();
    final sems = await db.getSemesters();
    final subs = await db.getAllSubjects();
    
    if (mounted) {
      setState(() {
        _departments = depts;
        _semesters = sems;
        _allSubjects = subs;
      });
    }
  }

  void _fetchSections() async {
    if (_selectedDept == null || _selectedSem == null) return;
    
    final db = DatabaseService();
    final secs = await db.getSections(_selectedDept!, _selectedSem!);
    if (mounted) setState(() => _sections = secs);
  }

  @override
  void didUpdateWidget(TeacherHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profName != oldWidget.profName) _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    final today = DateTime.now().weekday;
    try {
      final response = await Supabase.instance.client
          .from('timetable')
          .select()
          .eq('professor', widget.profName)
          .gte('day_of_week', today)
          .order('day_of_week', ascending: true)
          .order('start_hour', ascending: true)
          .limit(4);
      if (mounted) setState(() => _upcomingClasses = List<Map<String, dynamic>>.from(response));
    } catch (e) { /* silent */ }
  }

  Future<int> _recognizeStudents() async {
    final now = DateTime.now();
    final day = now.weekday;
    final hour = now.hour;
    try {
      final response = await Supabase.instance.client
          .rpc('get_students_for_teacher_class', params: {
            'teacher_name_input': widget.profName,
            'day_input': day,
            'hour_input': hour,
          });
      List<dynamic> data = response as List<dynamic>;
      return data.length;
    } catch (e) {
      return 0;
    }
  }

  void _toggleAttendance() async {
    if (widget.isAdvertising) {
      _stopListeningToDatabase();
      widget.onClassStateChanged(false, widget.currentSubject, widget.currentSection, widget.currentYear);
    } else {
      if (widget.profName.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile loading... or please check settings.")));
         return;
      }
      
      int expectedStudents = await _recognizeStudents();
      int sectionNum = 1;
      if (widget.currentSection.endsWith("B")) sectionNum = 2;
      if (widget.currentSection.endsWith("C")) sectionNum = 3;
      int beaconCode = (widget.currentYear * 10) + sectionNum;

      debugPrint("📡 Broadcasting Code $beaconCode for ${widget.currentSubject}");

      // --- BLE CODE HERE (Uncomment for Real Device) ---
      
      final AdvertiseData data = AdvertiseData(
        includeDeviceName: false,
        manufacturerId: 0xFFFF,
        manufacturerData: Uint8List.fromList([0xBE, 0xAC, beaconCode]),
      );
      await FlutterBlePeripheral().start(advertiseData: data);
      
      
      _startListeningToDatabase();
      widget.onClassStateChanged(true, widget.currentSubject, widget.currentSection, widget.currentYear);
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Class Started! Expected: $expectedStudents Students"),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  void _loadClassConfig(Map<String, dynamic> cls) {
    if (widget.isAdvertising) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stop current class first!")));
      return;
    }
    widget.onClassStateChanged(false, cls['subject'], cls['section'], cls['year'] ?? 1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Loaded: ${cls['subject']}")));
  }

  void _startListeningToDatabase() {
    setState(() => _attendanceList.clear());
    _subscription = Supabase.instance.client
        .channel('public:attendance_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'attendance_logs',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['class_name'] == widget.currentSubject && newRecord['section'] == widget.currentSection) {
              setState(() {
                _attendanceList.insert(0, {
                  'student_id': newRecord['student_id'],
                  'time': newRecord['check_in_time'],
                });
              });
            }
          },
        )
        .subscribe();
  }

  void _stopListeningToDatabase() {
    if (_subscription != null) {
      Supabase.instance.client.removeChannel(_subscription!);
      _subscription = null;
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'ppt', 'pptx']);
    if (result != null) {
      setState(() => _attachedFiles.add({'type': 'file', 'name': result.files.first.name}));
    }
  }

  void _showResourceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Add Class Topic", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 15),
                  TextField(controller: _topicNameCtrl, decoration: const InputDecoration(labelText: "Topic Name", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _topicSummaryCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Summary / Notes", border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  Wrap(spacing: 8, children: _attachedFiles.map((f) => Chip(
                    label: Text(f['name']),
                    onDeleted: () => setSheetState(() => _attachedFiles.remove(f)),
                  )).toList()),
                  const SizedBox(height: 10),
                  Row(children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                         await _pickFile();
                         setSheetState((){}); 
                      },
                      icon: const Icon(Icons.upload_file), label: const Text("Upload PDF"),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: _youtubeLinkCtrl,
                      decoration: InputDecoration(
                        hintText: "YouTube Link",
                        suffixIcon: IconButton(icon: const Icon(Icons.add_circle, color: Colors.red), onPressed: (){
                          if (_youtubeLinkCtrl.text.isNotEmpty) {
                            setSheetState(() => _attachedFiles.add({'type': 'youtube', 'name': 'Video Link', 'url': _youtubeLinkCtrl.text}));
                            _youtubeLinkCtrl.clear();
                          }
                        })
                      ),
                    ))
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Topic Posted! (Simulated)")));
                         _attachedFiles.clear(); _topicNameCtrl.clear(); _topicSummaryCtrl.clear();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, padding: const EdgeInsets.symmetric(vertical: 15)),
                      child: const Text("POST TO CLASS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Dashboard"),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🎓 HEADER CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.deepPurple.shade900]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome,", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                  Text(widget.profName.isEmpty ? "Professor" : widget.profName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.class_, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text("Y${widget.currentYear} • ${widget.currentDepartment} • Sec ${widget.currentSection}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 📅 UPCOMING CLASSES
            if (_upcomingClasses.isNotEmpty) ...[
              const Align(alignment: Alignment.centerLeft, child: Text(" Next Classes", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _upcomingClasses.length,
                  itemBuilder: (context, index) {
                    final cls = _upcomingClasses[index];
                    return GestureDetector(
                      onTap: () => _loadClassConfig(cls),
                      child: Container(
                        width: 190,
                        margin: const EdgeInsets.only(right: 15),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                               Text("${cls['start_hour']}:00", style: TextStyle(color: Colors.blue.shade400, fontWeight: FontWeight.bold)),
                               Text(cls['room_number'] ?? "CR-402", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                             ]),
                             Text(cls['subject'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                             Text("${cls['section']} (${cls['enrolled'] ?? 64} Students)", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],


            // 🔴 START BUTTON
            Center(
              child: GestureDetector(
                onTap: _toggleAttendance,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 180, width: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isAdvertising ? Colors.red : cardColor,
                    border: Border.all(color: widget.isAdvertising ? Colors.red : Colors.purple.withValues(alpha: 0.3), width: 8),
                    boxShadow: [BoxShadow(color: (widget.isAdvertising ? Colors.red : Colors.purple).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.isAdvertising ? Icons.stop : Icons.sensors, size: 50, color: widget.isAdvertising ? Colors.white : Colors.purple),
                      const SizedBox(height: 8),
                      Text(widget.isAdvertising ? "STOP" : "START CLASS", style: TextStyle(color: widget.isAdvertising ? Colors.white : Colors.purple, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 📋 LIVE ATTENDANCE
            const Align(alignment: Alignment.centerLeft, child: Text(" Live Attendance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            const Divider(),
            _attendanceList.isEmpty
              ? Padding(padding: const EdgeInsets.all(20), child: Text(widget.isAdvertising ? "Waiting for students..." : "Class not started.", style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _attendanceList.length,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white, size: 16)),
                    title: Text(_attendanceList[i]['student_id']),
                    subtitle: Text("Checked in at ${_attendanceList[i]['time'].toString().substring(11,16)}"),
                  ),
                ),
             const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 📅 TAB 2: TIMETABLE VIEW
// ============================================================================
class TeacherTimetableView extends StatefulWidget {
  final String profName;
  const TeacherTimetableView({super.key, required this.profName});

  @override
  State<TeacherTimetableView> createState() => _TeacherTimetableViewState();
}

class _TeacherTimetableViewState extends State<TeacherTimetableView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  void _showAddClassDialog() {
    final subjectCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    String section = "A";
    int day = 1;
    int hour = 9;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Class"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: "Subject Name")),
              TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: "Room (e.g. CR-402)")),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(initialValue: day, items: List.generate(6, (i) => DropdownMenuItem(value: i+1, child: Text(_days[i]))), onChanged: (v) => day = v!, decoration: const InputDecoration(labelText: "Day")),
              DropdownButtonFormField<int>(initialValue: hour, items: List.generate(9, (i) => DropdownMenuItem(value: i+9, child: Text("${i+9}:00"))), onChanged: (v) => hour = v!, decoration: const InputDecoration(labelText: "Time")),
              DropdownButtonFormField<String>(initialValue: section, items: ['A', 'B', 'C'].map((e) => DropdownMenuItem(value: e, child: Text("Section $e"))).toList(), onChanged: (v) => section = v!, decoration: const InputDecoration(labelText: "Section")),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (subjectCtrl.text.isNotEmpty) {
                try {
                  await Supabase.instance.client.from('timetable').insert({
                    'teacher_id': Supabase.instance.client.auth.currentUser!.id,
                    'subject_code': subjectCtrl.text,
                    'room_number': roomCtrl.text,
                    'day_of_week': day,
                    'start_time': "${hour.toString().padLeft(2, '0')}:00:00",
                    'end_time': "${(hour+1).toString().padLeft(2, '0')}:00:00",
                    'section': "Section-$section",
                  }).select();
                  
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    setState(() {}); // Refresh
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text("Error adding class: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text("ADD"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Weekly Schedule"),
        bottom: TabBar(
          controller: _tabController,
          tabs: _days.map((d) => Tab(text: d)).toList(),
          labelColor: Colors.purple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.purple,
        ),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddClassDialog)],
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(6, (dayIndex) {
          return FutureBuilder(
            future: Supabase.instance.client.from('timetable').select().eq('teacher_id', Supabase.instance.client.auth.currentUser!.id).eq('day_of_week', dayIndex + 1).order('start_time', ascending: true),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final classes = snapshot.data as List<dynamic>;
              if (classes.isEmpty) return const Center(child: Text("No classes.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final cls = classes[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(cls['start_time'].toString().substring(0, 5), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                      ),
                      title: Text(cls['subject_code'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${cls['section']} • Room: ${cls['room_number'] ?? 'TBD'}"),
                      trailing: IconButton(
                         icon: const Icon(Icons.delete, color: Colors.red),
                         onPressed: () async {
                            await Supabase.instance.client.from('timetable').delete().eq('id', cls['id']);
                            setState((){});
                         },
                      ),
                    ),
                  );
                },
              );
            },
          );
        }),
      ),
    );
  }
}

// ============================================================================
// 📝 TAB 3: TOPICS VIEW
// ============================================================================
class TeacherTopicsView extends StatefulWidget {
  const TeacherTopicsView({super.key});

  @override
  State<TeacherTopicsView> createState() => _TeacherTopicsViewState();
}

class _TeacherTopicsViewState extends State<TeacherTopicsView> {
  final TextEditingController _topicNameCtrl = TextEditingController();
  final TextEditingController _topicSummaryCtrl = TextEditingController();
  final TextEditingController _youtubeLinkCtrl = TextEditingController();
  final List<Map<String, dynamic>> _attachedFiles = [];
  
  List<Map<String, dynamic>> _subjects = [];
  String? _selectedSubject;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('timetable')
          .select('subject_code')
          .eq('teacher_id', user.id);
      
      final Map<String, bool> unique = {};
      for (var item in data) {
        unique[item['subject_code']] = true;
      }
      
      setState(() {
        _subjects = unique.keys.map((e) => {'subject_code': e}).toList();
        if (_subjects.isNotEmpty) {
          _selectedSubject = _subjects.first['subject_code'];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, 
      allowedExtensions: ['pdf', 'ppt', 'pptx'],
      withData: true, // Important for mobile
    );
    if (result != null && result.files.first.bytes != null) {
      final file = result.files.first;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      
      try {
        // Upload to Supabase Storage
        await Supabase.instance.client.storage
            .from('academic_files')
            .uploadBinary(fileName, file.bytes!);
        
        final url = Supabase.instance.client.storage
            .from('academic_files')
            .getPublicUrl(fileName);
        
        setState(() => _attachedFiles.add({
          'type': 'file', 
          'name': file.name,
          'url': url,
        }));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Uploaded: ${file.name}"), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addYoutubeLink() {
    if (_youtubeLinkCtrl.text.isNotEmpty) {
      setState(() => _attachedFiles.add({
        'type': 'youtube', 
        'name': 'Video Link', 
        'url': _youtubeLinkCtrl.text
      }));
      _youtubeLinkCtrl.clear();
    }
  }

  Future<void> _postTopic() async {
    if (_topicNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter topic name"), backgroundColor: Colors.orange)
      );
      return;
    }
    
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a subject"), backgroundColor: Colors.orange)
      );
      return;
    }
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      // Get URL from attachments (file or youtube)
      String? resourceUrl;
      if (_attachedFiles.isNotEmpty) {
        final fileAttachment = _attachedFiles.where((f) => f['type'] == 'file' && f['url'] != null).firstOrNull;
        final youtubeAttachment = _attachedFiles.where((f) => f['type'] == 'youtube').firstOrNull;
        resourceUrl = fileAttachment?['url'] ?? youtubeAttachment?['url'];
      }
      
      // Save to class_resources table
      // resource_type must be: 'pdf', 'ppt', 'video', or 'link'
      String resourceType = 'pdf';
      if (_attachedFiles.isNotEmpty) {
        final firstFile = _attachedFiles.first;
        if (firstFile['type'] == 'youtube') {
          resourceType = 'video';
        } else if (firstFile['name']?.toString().endsWith('.ppt') == true || 
                   firstFile['name']?.toString().endsWith('.pptx') == true) {
          resourceType = 'ppt';
        }
      }
      
      await Supabase.instance.client.from('class_resources').insert({
        'subject_code': _selectedSubject,
        'title': _topicNameCtrl.text,
        'file_url': resourceUrl,
        'resource_type': resourceType,
        'teacher_id': user?.id,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Topic '${_topicNameCtrl.text}' posted to $_selectedSubject!"), 
          backgroundColor: Colors.green
        )
      );
      
      // Clear form
      _topicNameCtrl.clear();
      _topicSummaryCtrl.clear();
      _attachedFiles.clear();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error posting topic: $e"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Topic"),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Subject", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_subjects.isEmpty)
                    const Text("No subjects assigned", style: TextStyle(color: Colors.grey))
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _subjects.map((s) => DropdownMenuItem(
                        value: s['subject_code'] as String,
                        child: Text(s['subject_code'] as String),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedSubject = val),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Topic Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Topic Details", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _topicNameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Topic Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _topicSummaryCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Summary / Notes",
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Attachments
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  if (_attachedFiles.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _attachedFiles.map((f) => Chip(
                        avatar: Icon(f['type'] == 'youtube' ? Icons.play_circle : Icons.insert_drive_file, size: 18),
                        label: Text(f['name'], style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() => _attachedFiles.remove(f)),
                      )).toList(),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text("Upload PDF"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade100,
                            foregroundColor: Colors.purple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _youtubeLinkCtrl,
                          decoration: const InputDecoration(
                            hintText: "YouTube Link",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link, color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _addYoutubeLink,
                        icon: const Icon(Icons.add_circle, color: Colors.red, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Post Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _postTopic,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send),
                label: const Text("POST TO CLASS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 📬 TAB 4: REQUESTS VIEW
// ============================================================================
class TeacherRequestsView extends StatefulWidget {
  const TeacherRequestsView({super.key});

  @override
  State<TeacherRequestsView> createState() => _TeacherRequestsViewState();
}

class _TeacherRequestsViewState extends State<TeacherRequestsView> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // 1. Get this teacher's assigned subjects
      final teacherSubjects = await Supabase.instance.client
          .from('timetable')
          .select('subject_code')
          .eq('teacher_id', user.id);
      
      final subjectCodes = teacherSubjects
          .map((s) => s['subject_code'] as String)
          .toSet()
          .toList();
      
      debugPrint("Teacher subjects: $subjectCodes");
      
      if (subjectCodes.isEmpty) {
        setState(() {
          _requests = [];
          _isLoading = false;
        });
        return;
      }
      
      // 2. Fetch requests only for teacher's subjects
      final data = await Supabase.instance.client
          .from('attendance_correction_requests')
          .select()
          .eq('status', 'Pending')
          .inFilter('subject_code', subjectCodes);
      
      // 3. Fetch student info for each request
      final List<Map<String, dynamic>> enrichedRequests = [];
      for (var req in data) {
        final studentId = req['student_id'];
        if (studentId != null) {
          try {
            final student = await Supabase.instance.client
                .from('students')
                .select('name, email')
                .eq('user_id', studentId)
                .maybeSingle();
            
            enrichedRequests.add({
              ...req,
              'student_name': student?['name'] ?? 'Unknown',
              'student_email': student?['email'] ?? '',
            });
          } catch (e) {
            enrichedRequests.add({...req, 'student_name': 'Unknown', 'student_email': ''});
          }
        } else {
          enrichedRequests.add({...req, 'student_name': 'Unknown', 'student_email': ''});
        }
      }
      
      debugPrint("Loaded ${enrichedRequests.length} pending requests for this teacher");
      
      setState(() {
        _requests = enrichedRequests;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading requests: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRequest(String requestId, bool approve) async {
    try {
      if (approve) {
        // 1. Get the request details first
        final request = await Supabase.instance.client
            .from('attendance_correction_requests')
            .select()
            .eq('id', requestId)
            .single();
        
        // 2. Add attendance record for this student/subject
        await Supabase.instance.client.from('attendance_logs').insert({
          'student_id': request['student_id'],
          'subject': request['subject_code'],
          'status': 'Present',
        });
      }
      
      // 3. Update request status
      await Supabase.instance.client
          .from('attendance_correction_requests')
          .update({
            'status': approve ? 'Approved' : 'Rejected',
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? "Request Approved ✓ Attendance Added!" : "Request Rejected"),
          backgroundColor: approve ? Colors.green : Colors.red,
        ),
      );
      
      _loadRequests(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Correction Requests"),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadRequests();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text("No pending requests", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final studentName = req['student_name'] ?? req['student_id'] ?? 'Student';
                    final studentEmail = req['student_email'] ?? '';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: const Icon(Icons.person, color: Colors.orange),
                            ),
                            title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(studentEmail, style: const TextStyle(fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text("Pending", style: TextStyle(color: Colors.orange, fontSize: 12)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.book, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text("Subject: ${req['subject_code'] ?? 'N/A'}", style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text("Date: ${req['date_of_absence'] ?? 'N/A'}", style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                if (req['reason'] != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.note, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text("Reason: ${req['reason']}", style: const TextStyle(fontSize: 13))),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _handleRequest(req['id'].toString(), false),
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    label: const Text("Reject", style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _handleRequest(req['id'].toString(), true),
                                    icon: const Icon(Icons.check),
                                    label: const Text("Approve"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================================
// ⚙️ TAB 5: SETTINGS VIEW
// ============================================================================
class TeacherSettingsView extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final String profName;
  final VoidCallback onEditProfile;

  const TeacherSettingsView({super.key, required this.isDarkMode, required this.onThemeChanged, required this.profName, required this.onEditProfile});

  @override
  State<TeacherSettingsView> createState() => _TeacherSettingsViewState();
}

class _TeacherSettingsViewState extends State<TeacherSettingsView> {
  List<Map<String, dynamic>> _assignedSubjects = [];
  String? _selectedSubject;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedSubjects();
  }

  Future<void> _loadAssignedSubjects() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get subjects this teacher is assigned to from timetable
      final data = await Supabase.instance.client
          .from('timetable')
          .select('subject_code, section, semester')
          .eq('teacher_id', user.id);
      
      // Remove duplicates by subject_code
      final Map<String, Map<String, dynamic>> uniqueSubjects = {};
      for (var item in data) {
        final code = item['subject_code'] as String;
        if (!uniqueSubjects.containsKey(code)) {
          uniqueSubjects[code] = item;
        }
      }
      
      setState(() {
        _assignedSubjects = uniqueSubjects.values.toList();
        if (_assignedSubjects.isNotEmpty) {
          _selectedSubject = _assignedSubjects.first['subject_code'];
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading subjects: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          ListTile(
            leading: const Icon(Icons.person, color: Colors.blue),
            title: const Text("Edit Profile"),
            subtitle: Text("Current: ${widget.profName}"),
            onTap: widget.onEditProfile,
          ),
          const Divider(),
          
          // Subjects Section
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.book, color: Colors.purple),
                    SizedBox(width: 8),
                    Text("My Subjects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_assignedSubjects.isEmpty)
                  const Text("No subjects assigned yet", style: TextStyle(color: Colors.grey))
                else
                  Column(
                    children: _assignedSubjects.map((subject) {
                      final code = subject['subject_code'] as String;
                      final section = subject['section'] ?? 'A';
                      final semester = subject['semester'] ?? 5;
                      final year = ((semester - 1) ~/ 2) + 1;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _selectedSubject == code 
                              ? Colors.purple.withValues(alpha: 0.1) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedSubject == code 
                                ? Colors.purple 
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: code,
                          groupValue: _selectedSubject,
                          activeColor: Colors.purple,
                          title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Year $year • Section $section"),
                          onChanged: (value) {
                            setState(() => _selectedSubject = value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Selected: $code"), backgroundColor: Colors.purple),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          
          const Divider(),
          SwitchListTile(
            title: const Text("Dark Mode"),
            subtitle: const Text("GOAT Mode 🐐"),
            value: widget.isDarkMode,
            activeThumbColor: Colors.purple,
            secondary: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onChanged: widget.onThemeChanged,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () async {
              // 1. Sign out from Supabase
              await Supabase.instance.client.auth.signOut();
              
              // 2. Check if the widget is still on screen
              if (context.mounted) {
                // 3. Go to Login Screen manually (No Named Route needed)
                // We use MaterialPageRoute here because we imported main.dart
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()), 
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