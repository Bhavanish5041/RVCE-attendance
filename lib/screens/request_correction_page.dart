import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class RequestCorrectionPage extends StatefulWidget {
  final String email;
  const RequestCorrectionPage({super.key, required this.email});

  @override
  State<RequestCorrectionPage> createState() => _RequestCorrectionPageState();
}

class _RequestCorrectionPageState extends State<RequestCorrectionPage> {
  // Form State
  String _selectedType = 'Medical Leave';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _subjectsController = TextEditingController();
  
  // Date Selection
  DateTimeRange? _selectedDateRange;
  
  // File Selection
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;

  // Options
  final List<String> _requestTypes = ['Medical Leave', 'College Event', 'General Inquiry'];

  // 1. PICK FILE (PDF/Images)
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf'],
    );

    if (result != null) {
      // Check Size (Limit 5MB)
      if (result.files.single.size > 5 * 1024 * 1024) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File too large! Max 5MB.")));
        }
        return;
      }

      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  // 2. PICK DATE RANGE
  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2026),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(primaryColor: Colors.purple, colorScheme: const ColorScheme.light(primary: Colors.purple)),
          child: child!,
        );
      }
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  // 3. SUBMIT FORM
  Future<void> _submitRequest() async {
    if (_selectedDateRange == null || _subjectsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!")));
      return;
    }
    
    if ((_selectedType == 'Medical Leave' || _selectedType == 'College Event') && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload proof document!")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // API expects single date, invalidating range for now or taking start
      final DateTime dateOfAbsence = _selectedDateRange!.start;
      
      await DatabaseService().submitCorrectionRequest(
        requestType: _selectedType,
        date: dateOfAbsence,
        subjectCode: _subjectsController.text,
        reason: _reasonController.text.isEmpty ? "No description" : _reasonController.text,
        proofFile: _selectedFile,
      );

      if (mounted) {
        Navigator.pop(context); // Close Page
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted Successfully!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Request Correction")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. REQUEST TYPE DROPDOWN
            const Text("Request Type", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  items: _requestTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // B. DYNAMIC INSTRUCTIONS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedType == "Medical Leave" ? "Please upload a valid Medical Certificate (PDF/JPG)." :
                      _selectedType == "College Event" ? "Upload Permission Letter or Participation Cert." :
                      "Describe your issue clearly for review.",
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // C. FORM FIELDS
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: _selectedType == "College Event" ? "Event Name & Organizer" : "Reason / Description",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 15),

            GestureDetector(
              onTap: _pickDateRange,
              child: AbsorbPointer(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: _selectedDateRange == null 
                        ? "Select Dates of Absence" 
                        : "${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.date_range),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _subjectsController,
              decoration: const InputDecoration(
                labelText: "Affected Subjects (e.g., AI, Networks)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
            ),
            
            const SizedBox(height: 20),

            // D. FILE UPLOAD SECTION
            if (_selectedType != "General Inquiry") ...[
              const Text("Proof Document (Max 5MB)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey.shade100,
                  ),
                  child: _selectedFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload, size: 30, color: Colors.grey),
                            Text("Tap to upload PDF, JPG, PNG", style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 30, color: Colors.green),
                            Text(_fileName ?? "File Selected", style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text("Tap to change", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                ),
              ),
            ],

            const SizedBox(height: 30),

            // E. SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: _isUploading 
                   ? const CircularProgressIndicator(color: Colors.white) 
                   : const Text("SUBMIT REQUEST", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}