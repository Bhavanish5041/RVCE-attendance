import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // To open PDFs
import '../services/database_service.dart';

class TeacherReviewPage extends StatelessWidget {
  const TeacherReviewPage({super.key});

  // Helper to open the proof link
  Future<void> _openProof(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Requests")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService().getPendingCorrectionRequests(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all, size: 60, color: Colors.green.shade200),
                  const SizedBox(height: 10),
                  const Text("All caught up! No pending requests."),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Type & Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                            label: Text(req['request_type'], style: const TextStyle(color: Colors.white)),
                            backgroundColor: req['request_type'] == 'Medical Leave' ? Colors.red.shade400 : Colors.blue.shade400,
                          ),
                          Text(req['created_at'].substring(0, 10), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // Details
                      Text("Reason: ${req['reason']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("Dates: ${req['dates']}"),
                      Text("Subjects: ${req['subjects']}"),
                      
                      const SizedBox(height: 15),
                      
                      // Proof Button
                      if (req['proof_url'] != null)
                        OutlinedButton.icon(
                          onPressed: () => _openProof(req['proof_url']),
                          icon: const Icon(Icons.attachment),
                          label: const Text("View Proof Document"),
                        ),

                      const Divider(height: 30),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => DatabaseService().reviewCorrectionRequest(requestId: req['id'], status: 'Rejected'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text("Reject"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await DatabaseService().reviewCorrectionRequest(
                                  requestId: req['id'], 
                                  status: 'Approved'
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Approved & Attendance Updated!")));
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text("Approve"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}