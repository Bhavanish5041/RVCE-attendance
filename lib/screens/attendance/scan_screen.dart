import 'package:flutter/material.dart';
// Import Database Service if needed later
// import '../../services/database_service.dart';

class ScanScreen extends StatefulWidget {
  final String subjectName; // Passed from the previous screen
  
  const ScanScreen({super.key, required this.subjectName});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isScanning = true;
  String _statusMessage = "Searching for class beacon...";

  @override
  void initState() {
    super.initState();
    // 1. Setup the Animation (2 seconds per pulse)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // 2. Start the actual Scanning Logic immediately
    _startScanning();
  }

  Future<void> _startScanning() async {
    // Simulate scanning delay for the animation effect
    await Future.delayed(const Duration(seconds: 3));

    // HERE: Call your DatabaseService().markAttendance()
    // For now, we simulate a success:
    if (mounted) {
      setState(() {
        _isScanning = false;
        _controller.stop();
        _statusMessage = "Connected to ${widget.subjectName}!";
      });
      
      // Show Success Dialog
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("Attendance Marked!"),
          ],
        ),
        content: Text("You have successfully joined ${widget.subjectName}."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close Dialog
              Navigator.pop(context); // Go back to Dashboard
            },
            child: const Text("Done"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937), // Navy Background
      appBar: AppBar(
        title: Text("Joining ${widget.subjectName}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // THE ANIMATION STACK
            Stack(
              alignment: Alignment.center,
              children: [
                // Pulse 1 (Big)
                if (_isScanning)
                  _buildPulseCircle(300, 0.5),
                // Pulse 2 (Small)
                if (_isScanning)
                  _buildPulseCircle(200, 1.0),
                
                // Center Icon (Bluetooth/Beacon)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Icon(
                    _isScanning ? Icons.bluetooth_searching : Icons.check,
                    size: 50,
                    color: _isScanning ? Colors.blue : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  // Helper builder for the animated circles
  Widget _buildPulseCircle(double maxSize, double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate a wave effect (0.0 to 1.0)
        final double t = (_controller.value + delay) % 1.0;
        final double size = maxSize * t;
        final double opacity = 1.0 - t; // Fade out as it gets bigger

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue.withValues(alpha: opacity),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
