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
  String _section = "Section-A";
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
      final data = await Supabase.instance.client
          .from('teacher_profiles')
          .select()
          .eq('email', _currentUser!.email!)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _profName = data['name'];
          _subject = data['default_subject'] ?? "";
          _section = data['default_section'] ?? "Section-A";
          _year = data['default_year'] ?? 1;
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
        if (mounted) {
           Future.delayed(const Duration(milliseconds: 500), () => _showSetupDialog(context));
        }
      }
    } catch (e) {
      print("Error loading profile: $e");
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
                    Navigator.pop(ctx);
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
              currentSection: _section,
              currentYear: _year,
              isAdvertising: _isAdvertising,
              onClassStateChanged: _updateClassState,
            ),
            TeacherTimetableView(profName: _profName),
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
  final String currentSection;
  final int currentYear;
  final bool isAdvertising;
  final Function(bool, String, String, int) onClassStateChanged;

  const TeacherHomeView({
    super.key,
    required this.profName,
    required this.currentSubject,
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

      print("📡 Broadcasting Code $beaconCode for ${widget.currentSubject}");

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showResourceSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text("Add Topic", style: TextStyle(color: Colors.white)),
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
                        Text("${widget.currentSubject} • Year ${widget.currentYear} • ${widget.currentSection}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

            // 🛠️ MANUAL CLASS START
            if (!widget.isAdvertising) ...[ // Only show if class not running
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text("Manual Class Start", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     const SizedBox(height: 15),
                     // Row 1: Dept & Sem
                     Row(children: [
                       Expanded(child: DropdownButtonFormField<String>(
                         decoration: const InputDecoration(labelText: "Department", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                         value: _selectedDept,
                         items: _departments.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                         onChanged: (val) {
                           setState(() { _selectedDept = val; _selectedSection = null; });
                           _fetchSections();
                         },
                       )),
                       const SizedBox(width: 10),
                       Expanded(child: DropdownButtonFormField<int>(
                         decoration: const InputDecoration(labelText: "Semester", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                         value: _selectedSem,
                         items: _semesters.map((e) => DropdownMenuItem(value: e, child: Text("Sem $e", style: const TextStyle(fontSize: 12)))).toList(),
                         onChanged: (val) {
                           setState(() { _selectedSem = val; _selectedSection = null; });
                           _fetchSections();
                         },
                       )),
                     ]),
                     const SizedBox(height: 10),
                     // Row 2: Section & Subject
                     Row(children: [
                       Expanded(child: DropdownButtonFormField<String>(
                         decoration: const InputDecoration(labelText: "Section", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                         value: _selectedSection,
                         items: _sections.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                         onChanged: (val) => setState(() => _selectedSection = val),
                       )),
                       const SizedBox(width: 10),
                       Expanded(flex: 2, child: DropdownButtonFormField<String>(
                         decoration: const InputDecoration(labelText: "Subject", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                         value: _selectedSubjectCode,
                         isExpanded: true,
                         items: _allSubjects.map((e) => DropdownMenuItem(value: e['course_code'].toString(), child: Text(e['name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                         onChanged: (val) {
                            final sub = _allSubjects.firstWhere((e) => e['course_code'] == val, orElse: () => {});
                            setState(() { _selectedSubjectCode = val; _selectedSubjectName = sub['name']; });
                         },
                       )),
                     ]),
                     const SizedBox(height: 15),
                     SizedBox(
                       width: double.infinity,
                       child: ElevatedButton.icon(
                         onPressed: (_selectedDept != null && _selectedSem != null && _selectedSection != null && _selectedSubjectCode != null)
                             ? () {
                                 // Update State for Class Start
                                 widget.onClassStateChanged(false, _selectedSubjectName ?? "Unknown", _selectedSection!, _selectedSem!.toInt() ~/ 2 + 1); // Approx year 
                                 // Trigger start (reuse existing logic)
                                 _toggleAttendance(); 
                               }
                             : null,
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                         icon: const Icon(Icons.play_arrow),
                         label: const Text("START CLASS NOW"),
                       ),
                     )
                   ],
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
    String section = "Section-A";
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
              DropdownButtonFormField(initialValue: day, items: List.generate(6, (i) => DropdownMenuItem(value: i+1, child: Text(_days[i]))), onChanged: (v) => day = v!, decoration: const InputDecoration(labelText: "Day")),
              DropdownButtonFormField(initialValue: hour, items: List.generate(9, (i) => DropdownMenuItem(value: i+9, child: Text("${i+9}:00"))), onChanged: (v) => hour = v!, decoration: const InputDecoration(labelText: "Time")),
               DropdownButtonFormField(initialValue: section, items: ['Section-A', 'Section-B', 'Section-C'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => section = v!, decoration: const InputDecoration(labelText: "Section")),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (subjectCtrl.text.isNotEmpty) {
                await Supabase.instance.client.from('timetable').insert({
                  'professor': widget.profName,
                  'subject': subjectCtrl.text,
                  'room_number': roomCtrl.text,
                  'day_of_week': day,
                  'start_hour': hour,
                  'section': section,
                });
                Navigator.pop(ctx);
                setState(() {}); // Refresh
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
            future: Supabase.instance.client.from('timetable').select().eq('professor', widget.profName).eq('day_of_week', dayIndex + 1).order('start_hour', ascending: true),
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
                        child: Text("${cls['start_hour']}:00", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                      ),
                      title: Text(cls['subject'], style: const TextStyle(fontWeight: FontWeight.bold)),
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
// ⚙️ TAB 3: SETTINGS VIEW
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person, color: Colors.blue),
            title: const Text("Edit Profile"),
            subtitle: Text("Current: ${widget.profName}"),
            onTap: widget.onEditProfile,
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