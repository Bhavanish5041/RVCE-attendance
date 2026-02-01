import 'package:flutter/material.dart';
import '../services/database_service.dart';

class PriorityNotifications extends StatefulWidget {
  final String userEmail; // We don't really need email anymore as DB uses auth, but keeping for compatibility
  const PriorityNotifications({super.key, required this.userEmail});

  @override
  State<PriorityNotifications> createState() => _PriorityNotificationsState();
}

class _PriorityNotificationsState extends State<PriorityNotifications> {
  List<Map<String, dynamic>> _attendance = [];
  Map<String, dynamic>? _upcomingClass;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = DatabaseService();
      
      // 1. Fetch Attendance (to find low attendance)
      final attendance = await db.getAttendanceSummary();
      
      // 2. Fetch Timetable (to find upcoming class)
      final today = DateTime.now().weekday;
      final timetable = await db.getTimetable(today);
      
      // Find next class based on current time
      final now = DateTime.now();
      final currentTimeStr = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}";
      
      Map<String, dynamic>? next;
      // Simple string comparison for 'HH:MM:SS' works for sorting, 
      // but to be precise we should parse. 
      // Assuming timetable returns sorted by start_time.
      for (var t in timetable) {
        if ((t['start_time'] as String).compareTo(currentTimeStr) > 0) {
          next = t;
          break; // First one after now
        }
      }

      if (mounted) {
        setState(() {
          _attendance = attendance;
          _upcomingClass = next;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading priority data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LinearProgressIndicator();

    // Filter for low attendance (< 75%)
    final lowAttendanceSubjects = _attendance.where((a) => (a['percentage'] as num) < 75).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Priority Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        
        // 1. UPCOMING CLASS CARD
        if (_upcomingClass != null) _buildUpcomingClassCard(_upcomingClass!),
        if (_upcomingClass == null) 
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [Icon(Icons.check, color: Colors.green), SizedBox(width: 10), Text("No more classes today!")]),
          ),
          
        const SizedBox(height: 10),

        // 2. ATTENDANCE WARNINGS
        if (lowAttendanceSubjects.isEmpty)
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [Icon(Icons.thumb_up, color: Colors.green), SizedBox(width: 10), Text("Attendance is good!")]),
          )
        else
          ...lowAttendanceSubjects.map((a) => _buildAttendanceCard(a)),
      ],
    );
  }

  // --- WIDGET: UPCOMING CLASS ---
  Widget _buildUpcomingClassCard(Map<String, dynamic> data) {
    final subjectName = data['subjects']['name'] ?? 'Unknown';
    final room = data['room_number'] ?? 'TBD';
    final time = "${data['start_time'].toString().substring(0,5)} - ${data['end_time'].toString().substring(0,5)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(left: BorderSide(color: Colors.blue.shade800, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_filled, color: Colors.blue),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("UPCOMING: $subjectName", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("$time • $room", style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET: ATTENDANCE WARNING ---
  Widget _buildAttendanceCard(Map<String, dynamic> data) {
    // data structure from `get_student_attendance_summary` RPC:
    // {subject_code, subject_name, total_classes, attended_classes, percentage}
    final subject = data['subject_name'] ?? data['subject_code'];
    final pct = (data['percentage'] as num).toDouble();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: const Border(left: BorderSide(color: Colors.red, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$subject: ${pct.toStringAsFixed(1)}%", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const Text("Attendance below 75%. Please attend upcoming classes.", 
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}