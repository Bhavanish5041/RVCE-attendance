import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart'; 
import '../services/database_service.dart';
import 'login_screen.dart';

// ==========================================
// 1. MAIN STUDENT SCREEN (NAVIGATION)
// ==========================================
class StudentScreen extends StatefulWidget {
  final String studentEmail;
  const StudentScreen({super.key, this.studentEmail = "student.ai23@rvce.edu.in"});

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
  ];

  @override
  void initState() {
    super.initState();
    _parseStudentData();
    _initSequence(); 
  }

  Future<void> _initSequence() async {
    // Try to register, but ignore errors for demo/offline logic
    await DatabaseService().registerStudent(widget.studentEmail); 
    await _requestPermissions();
    
    if (mounted) {
      setState(() {
        _pages = [
          DashboardPage(name: _displayName, email: widget.studentEmail),
          TimetablePage(email: widget.studentEmail), 
          SettingsPage(name: _displayName, email: widget.studentEmail), 
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
            if (_pages.length == 3 && _pages[0] is! Center) {
               _pages = [
                DashboardPage(name: _displayName, email: widget.studentEmail),
                TimetablePage(email: widget.studentEmail),
                SettingsPage(name: _displayName, email: widget.studentEmail),
              ];
            }
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
// 2. DASHBOARD PAGE (ANALYTICS + BUTTON)
// ==========================================
class DashboardPage extends StatefulWidget {
  final String name;
  final String email; 
  const DashboardPage({super.key, required this.name, required this.email});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<Map<String, dynamic>>? _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _analyticsFuture = DatabaseService().fetchFullAnalytics(widget.email);
    });
  }

  Future<void> _markAttendance(BuildContext context) async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Turn on Bluetooth!")));
      }
      return;
    }

    // [Attendance Logic kept same as provided code for brevity]
    int batch = 24; 
    try {
      String localPart = widget.email.split('@')[0];
      String batchPart = localPart.split('.')[1];
      String yearStr = batchPart.replaceAll(RegExp(r'[^0-9]'), ''); 
      batch = int.parse(yearStr);
    } catch (e) { /* silent */ }

    int currentYear = DateTime.now().year; 
    int myYear = (currentYear - 2000) - batch;
    if (myYear < 1) myYear = 1;
    if (myYear > 4) myYear = 4;

    String mySection = await DatabaseService().getStudentSection(widget.email);
    int sectionNum = 1; 
    if (mySection.endsWith("B")) sectionNum = 2;
    if (mySection.endsWith("C")) sectionNum = 3;

    int expectedCode = (myYear * 10) + sectionNum;
    
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    String foundClass = "";
    String foundSection = "";

    var subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.advertisementData.manufacturerData.containsKey(65535)) {
          List<int> data = r.advertisementData.manufacturerData[65535] ?? [];
          if (data.length >= 3 && data[0] == 0xBE && data[1] == 0xAC) {
            int teacherBeaconCode = data[2];
            if (teacherBeaconCode == expectedCode) {
              foundClass = "AI_ML"; // Simulating subject detection
              foundSection = mySection;
            }
          }
        }
      }
    });

    await Future.delayed(const Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    if (foundClass.isNotEmpty) {
      await DatabaseService().markAttendance(widget.email, foundClass, foundSection);
      if (context.mounted) _showSuccessDialog(context, foundClass);
      _refreshData();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No matching class beacon found."), backgroundColor: Colors.red));
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String className) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text("Attendance Marked!"),
        content: Text("Checked into: $className"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done"))],
      ),
    );
  }

  Future<void> _generatePdf(String subjectName, List<Map<String, dynamic>> logs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular(); 
    final boldFont = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text("Attendance Report", style: pw.TextStyle(font: boldFont, fontSize: 24)),
                    pw.Text("RVCE Smart Attendance", style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey)),
              ])),
              pw.SizedBox(height: 20),
              pw.Text("Student: ${widget.name}", style: pw.TextStyle(font: boldFont)),
              pw.Text("Subject: $subjectName", style: pw.TextStyle(font: font)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ["Date", "Day", "Time", "Status"],
                data: logs.map((log) {
                  final date = DateTime.parse(log['check_in_time']).toLocal();
                  return [DateFormat('yyyy-MM-dd').format(date), DateFormat('EEEE').format(date), DateFormat('hh:mm a').format(date), "Present"];
                }).toList(),
                headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
              ),
            ],
          );
        },
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: '${subjectName}_Report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Dark Mode Check
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      // 🟢 Use Theme background
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0, 
        backgroundColor: isDark ? Colors.grey[900] : Colors.white, 
        automaticallyImplyLeading: false,
        title: Row(children: [
            CircleAvatar(backgroundColor: Colors.purple.shade100, child: Text(widget.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Hi, ${widget.name}", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)), 
              Text("Here's your progress", style: const TextStyle(color: Colors.grey, fontSize: 12))
            ]),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.grey), onPressed: _refreshData)],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: Text("No Data Available"));
          
          final data = snapshot.data!;
          final subjects = data['subjects'] as List;
          final logs = data['recent_logs'] as List;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PriorityNotifications(userEmail: widget.email),
                const SizedBox(height: 20),
                Row(children: [
                    _buildStatCard("Streak", "${data['streak']} Days", Icons.local_fire_department, Colors.orange, isDark),
                    const SizedBox(width: 10),
                    _buildStatCard("Avg Rate", "${(data['monthly_rate'] as num).toStringAsFixed(0)}%", Icons.trending_up, Colors.blue, isDark),
                ]),
                const SizedBox(height: 15),

                // Request Correction
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => RequestCorrectionPage(email: widget.email)));
                    },
                    icon: const Icon(Icons.support_agent, color: Colors.purple),
                    label: const Text("Request Attendance Correction", style: TextStyle(color: Colors.purple)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.purple.shade200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                
                const SizedBox(height: 20),
                Text("Your Subjects", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) => _buildDetailedSubjectCard(context, subjects[index], isDark),
                ),
                const SizedBox(height: 20),
                Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date = DateTime.parse(log['check_in_time']).toLocal();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.check, size: 16, color: Colors.green)),
                      title: Text(log['class_name'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      subtitle: Text(DateFormat('MMM dd • hh:mm a').format(date), style: const TextStyle(color: Colors.grey)),
                      trailing: const Text("Present", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _markAttendance(context), backgroundColor: Colors.purple, icon: const Icon(Icons.bluetooth_searching, color: Colors.white), label: const Text("Mark Attendance", style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // 🟢 Fix
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)
      ), 
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color)), 
        const SizedBox(width: 10), 
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)), 
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12))
        ])
      ])
    ));
  }

  Widget _buildDetailedSubjectCard(BuildContext context, Map<String, dynamic> subject, bool isDark) {
    double pct = (subject['percentage'] as num).toDouble();
    Color color = pct >= 85 ? Colors.green : (pct >= 75 ? Colors.orange : Colors.red);
    int needed = subject['needed'];
    return GestureDetector(
      onTap: () => _showDetailedModal(context, subject),
      child: Container(
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // 🟢 Fix
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1)
        ), 
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subject['code'], style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 5), 
            Text(subject['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)), 
            Text("${subject['attended']}/${subject['total']} Classes", style: const TextStyle(color: Colors.grey, fontSize: 12))
          ]), 
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${pct.toInt()}%", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)), 
            if (needed > 0) Text("+$needed needed", style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 5), 
            LinearProgressIndicator(value: pct / 100, backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100, color: color, minHeight: 6, borderRadius: BorderRadius.circular(10))
          ])
        ])
      ),
    );
  }

  void _showDetailedModal(BuildContext context, Map<String, dynamic> subject) {
    double pct = (subject['percentage'] as num).toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => DraggableScrollableSheet(initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, builder: (_, controller) => Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), 
      child: FutureBuilder<List<Map<String, dynamic>>>(future: DatabaseService().fetchSubjectHistory(widget.email, subject['name']), builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data ?? [];
          return ListView(controller: controller, padding: const EdgeInsets.all(20), children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 20),
              Text(subject['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text("Course Code: ${subject['code']}", style: const TextStyle(color: Colors.grey)), const Divider(height: 30),
              SizedBox(height: 200, child: PieChart(PieChartData(sections: [PieChartSectionData(value: pct, color: Colors.green, title: "${pct.toInt()}%", radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), PieChartSectionData(value: 100.0 - pct, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, title: "", radius: 50)], centerSpaceRadius: 40))),
              const Center(child: Text("Attendance Distribution", style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 30),
              const Text("Class History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
              Container(decoration: BoxDecoration(color: isDark ? Colors.grey.shade900 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)), child: logs.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No classes attended yet."))) : ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: logs.length, separatorBuilder: (context, index) => const Divider(height: 1), itemBuilder: (context, index) { final log = logs[index]; final date = DateTime.parse(log['check_in_time']).toLocal(); return ListTile(title: Text(DateFormat('EEEE, MMM dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(DateFormat('hh:mm a').format(date)), trailing: const Text("Present", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))); })),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: logs.isEmpty ? null : () => _generatePdf(subject['name'], logs), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)), icon: const Icon(Icons.download), label: const Text("Download Official Report")))
          ]);
    }))));
  }
}

// ==========================================
// 3. TIMETABLE PAGE
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

  void _showAddDialog(BuildContext context) {
    // [Keeping dialog logic same]
    final subjectCtrl = TextEditingController();
    final profCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    int selectedTime = 9; 

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(title: Text("Add Class for ${_getDayName(_selectedDay)}"), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: "Subject Name", icon: Icon(Icons.book))), TextField(controller: profCtrl, decoration: const InputDecoration(labelText: "Professor", icon: Icon(Icons.person))), TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: "Room", icon: Icon(Icons.room))), const SizedBox(height: 20), Row(children: [const Icon(Icons.access_time, color: Colors.grey), const SizedBox(width: 15), const Text("Time: "), DropdownButton<int>(value: selectedTime, items: List.generate(9, (index) { int hour = 9 + index; return DropdownMenuItem(value: hour, child: Text("${hour > 12 ? hour - 12 : hour}:00 ${hour >= 12 ? 'PM' : 'AM'}")); }), onChanged: (val) => setDialogState(() => selectedTime = val!))])])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")), ElevatedButton(onPressed: () async { if (subjectCtrl.text.isNotEmpty) { await DatabaseService().addTimetableEntry(widget.email, _selectedDay, selectedTime, subjectCtrl.text, profCtrl.text, roomCtrl.text); if (context.mounted) Navigator.pop(context); } }, child: const Text("Add"))]);
      }));
  }

  void _deleteEntry(String id) {
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
    return FutureBuilder<String>(future: DatabaseService().getStudentSection(widget.email), builder: (context, sectionSnap) {
        if (!sectionSnap.hasData) return const Center(child: CircularProgressIndicator());
        String section = sectionSnap.data!;
        return StreamBuilder<List<Map<String, dynamic>>>(stream: Supabase.instance.client.from('timetable').stream(primaryKey: ['id']).eq('section', section).order('start_hour', ascending: true), builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final allClasses = snapshot.data!;
            final classes = allClasses.where((c) => c['day_of_week'] == _selectedDay).toList();
            if (classes.isEmpty) return const Center(child: Text("No classes today. Tap + to add."));
            return ListView.builder(padding: const EdgeInsets.all(16), itemCount: classes.length, itemBuilder: (context, index) { final item = classes[index]; int h = item['start_hour']; String time = "${h > 12 ? h - 12 : h}:00 ${h >= 12 ? 'PM' : 'AM'}"; return Dismissible(key: Key(item['id']), direction: DismissDirection.endToStart, background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)), onDismissed: (_) => _deleteEntry(item['id']), child: Card(color: cardColor, elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple.shade50, borderRadius: BorderRadius.circular(8)), child: Text(time.split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))), title: Text(item['subject'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${item['professor']} • ${item['room_number']}")))); });
        });
    });
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
    int hour = classData['start_hour'];
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
          Text("UPCOMING: ${classData['subject']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blue.shade100 : Colors.black)), 
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
    bool isDarkMode = themeNotifier.value == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), automaticallyImplyLeading: false),
      body: ListView(children: [const SizedBox(height: 20), ListTile(leading: CircleAvatar(backgroundColor: Colors.purple.shade100, child: Text(widget.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))), title: Text(widget.name), subtitle: Text(widget.email)), const Divider(), SwitchListTile(title: const Text("Dark Mode"), secondary: const Icon(Icons.dark_mode_outlined), value: isDarkMode, onChanged: (bool value) { setState(() { themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light; }); }), const Divider(), ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Log Out", style: TextStyle(color: Colors.red)), onTap: () async {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
           Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        }
      })]),
    );
  }
}

// ==========================================
// 6. REQUEST CORRECTION PAGE
// ==========================================
class RequestCorrectionPage extends StatefulWidget {
  final String email;
  const RequestCorrectionPage({super.key, required this.email});

  @override
  State<RequestCorrectionPage> createState() => _RequestCorrectionPageState();
}

class _RequestCorrectionPageState extends State<RequestCorrectionPage> {
  String _selectedType = 'Medical Leave';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _subjectsController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;
  final List<String> _requestTypes = ['Medical Leave', 'College Event', 'General Inquiry'];

  // ... [File pick and Date pick functions kept same]
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'png', 'pdf']);
    if (result != null) {
      if (result.files.single.size > 5 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File too large! Max 5MB.")));
        return;
      }
      setState(() { _selectedFile = File(result.files.single.path!); _fileName = result.files.single.name; });
    }
  }

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime(2026), builder: (context, child) => Theme(data: ThemeData.light().copyWith(primaryColor: Colors.purple, colorScheme: const ColorScheme.light(primary: Colors.purple)), child: child!));
    if (picked != null) setState(() => _selectedDateRange = picked);
  }

  Future<void> _submitRequest() async {
    if (_selectedDateRange == null || _subjectsController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!"))); return; }
    if ((_selectedType == 'Medical Leave' || _selectedType == 'College Event') && _selectedFile == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload proof document!"))); return; }

    setState(() => _isUploading = true);
    try {
      String dateString = "${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} to ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}";
      await DatabaseService().submitCorrectionRequest(email: widget.email, type: _selectedType, dates: dateString, subjects: _subjectsController.text, reason: _reasonController.text.isEmpty ? "No description" : _reasonController.text, file: _selectedFile, fileName: _fileName);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted Successfully!"), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: const Text("Request Correction")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Request Type", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedType, isExpanded: true, items: _requestTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _selectedType = val!)))),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.info, color: Colors.blue), const SizedBox(width: 10), Expanded(child: Text(_selectedType == "Medical Leave" ? "Please upload a valid Medical Certificate (PDF/JPG)." : _selectedType == "College Event" ? "Upload Permission Letter or Participation Cert." : "Describe your issue clearly for review.", style: const TextStyle(fontSize: 12, color: Colors.blue)))])),
            const SizedBox(height: 20),
            TextField(controller: _reasonController, decoration: InputDecoration(labelText: _selectedType == "College Event" ? "Event Name & Organizer" : "Reason / Description", border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.description)), maxLines: 2),
            const SizedBox(height: 15),
            GestureDetector(onTap: _pickDateRange, child: AbsorbPointer(child: TextField(decoration: InputDecoration(labelText: _selectedDateRange == null ? "Select Dates of Absence" : "${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}", border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.date_range))))),
            const SizedBox(height: 15),
            TextField(controller: _subjectsController, decoration: const InputDecoration(labelText: "Affected Subjects", border: OutlineInputBorder(), prefixIcon: Icon(Icons.book))),
            const SizedBox(height: 20),
            if (_selectedType != "General Inquiry") ...[
              const Text("Proof Document (Max 5MB)", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10),
              GestureDetector(onTap: _pickFile, child: Container(height: 100, width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.grey, style: BorderStyle.solid), borderRadius: BorderRadius.circular(10), color: isDark ? Colors.grey[800] : Colors.grey.shade100), child: _selectedFile == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload, size: 30, color: Colors.grey), Text("Tap to upload PDF, JPG, PNG", style: TextStyle(color: Colors.grey))]) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle, size: 30, color: Colors.green), Text(_fileName ?? "File Selected", style: const TextStyle(fontWeight: FontWeight.bold)), const Text("Tap to change", style: TextStyle(fontSize: 10, color: Colors.grey))]))),
            ],
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isUploading ? null : _submitRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white), child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text("SUBMIT REQUEST", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }
}