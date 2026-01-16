import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart'; // Import the new library

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  bool _isBroadcasting = false;
  String _activeClass = "";
  
  // The tool that makes the phone a beacon
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  final List<Map<String, String>> _myClasses = [
    {"name": "AI & ML", "code": "AI-301", "time": "09:00 AM", "room": "CR-405"},
    {"name": "Embedded Systems", "code": "EC-204", "time": "11:00 AM", "room": "Lab-2"},
    {"name": "Project Phase 1", "code": "AI-401", "time": "02:00 PM", "room": "Lab-1"},
  ];

  Future<void> _toggleBroadcast(String subjectName) async {
    // 1. If already on, turn it off
    if (_isBroadcasting) {
      await _blePeripheral.stop();
      setState(() {
        _isBroadcasting = false;
        _activeClass = "";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Attendance Stopped. Beacon Off.")),
        );
      }
      return;
    }

    // 2. If off, turn it on
    // We create a "Packet" that tells other phones who we are
    final AdvertiseData advertiseData = AdvertiseData(
      includeDeviceName: true, // Shout the name!
      // localName is the name the student will see
      localName: "RVCE_CLASS_$subjectName", 
    );

    // Start Advertising
    await _blePeripheral.start(advertiseData: advertiseData);
    
    setState(() {
      _isBroadcasting = true;
      _activeClass = subjectName;
    });

    if (mounted) _showBroadcastDialog(subjectName);
  }

  void _showBroadcastDialog(String subject) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Attendance Active"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_audio, size: 60, color: Colors.blueAccent),
            const SizedBox(height: 20),
            Text("Broadcasting:\nRVCE_CLASS_$subject", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Your phone is now a Beacon.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Run in Background")
          ),
          ElevatedButton(
            onPressed: () {
              _toggleBroadcast(""); // Stop everything
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Stop Attendance"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Portal"),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STATUS CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isBroadcasting ? Colors.green.shade700 : Colors.blueGrey.shade800,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(_isBroadcasting ? Icons.wifi_tethering : Icons.wifi_off, color: Colors.white, size: 40),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isBroadcasting ? "Attendance Active" : "Ready to Start",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        _isBroadcasting ? "Broadcasting: RVCE_CLASS_$_activeClass" : "Select a class below",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text("Today's Classes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _myClasses.length,
              itemBuilder: (context, index) {
                final cls = _myClasses[index];
                bool isThisClassActive = _activeClass == cls['name'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade50,
                      child: Text(cls['code']!.split('-')[1], style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(cls['name']!),
                    subtitle: Text("${cls['time']} • ${cls['room']}"),
                    trailing: ElevatedButton.icon(
                      onPressed: _isBroadcasting && !isThisClassActive 
                          ? null 
                          : () => _toggleBroadcast(cls['name']!),
                      icon: Icon(isThisClassActive ? Icons.stop_circle : Icons.sensors),
                      label: Text(isThisClassActive ? "Stop" : "Start"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isThisClassActive ? Colors.red : Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}