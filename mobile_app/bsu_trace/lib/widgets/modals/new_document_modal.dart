import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../../config.dart';
import '../../services/session_manager.dart';

class NewDocumentModal extends StatefulWidget {
  const NewDocumentModal({super.key});

  @override
  State<NewDocumentModal> createState() => _NewDocumentModalState();
}

class _NewDocumentModalState extends State<NewDocumentModal> {
  final TextEditingController _titleController = TextEditingController();
  
  List<dynamic> _processTypes = [];
  int? _selectedProcessId;
  
  bool _isVerified = false;
  bool _isSubmitting = false;
  List<String> _stops = ['Department Head', 'Dean\'s Office'];

  @override
  void initState() {
    super.initState();
    _fetchProcessTypes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // Fetch predefined process formulas from the database
  Future<void> _fetchProcessTypes() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types'));
      if (response.statusCode == 200) {
        setState(() {
          _processTypes = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching process types: $e');
    }
  }

  // Handle document submission
  Future<void> _submitDocument() async {
    // 1. Validation Check
    if (_titleController.text.trim().isEmpty || _selectedProcessId == null || !_isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and verify the document.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    final userId = SessionManager().userId;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      // 2. Network Post
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/documents'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'u_id': userId,
          'title': _titleController.text.trim(),
          'p_id': _selectedProcessId,
        }),
      );

      if (response.statusCode == 201) {
        // Success: Close the modal
        if (mounted) {
          Navigator.pop(context, true); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document successfully routed!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Failed to create document');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Helper to dynamically calculate Est Completion (7 days out)
  String _getEstimatedDate() {
    final date = DateTime.now().add(const Duration(days: 7));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFCF6F6),
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          Divider(color: Colors.red.shade100, height: 1),
          
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('DOCUMENT TITLE'),
                  const SizedBox(height: 8),
                  _buildTextField('e.g. Curriculum Revision Request'),
                  const SizedBox(height: 20),
                  
                  _buildLabel('PROCESS TYPE'),
                  const SizedBox(height: 8),
                  _buildDropdown('Select Process Type'),
                  const SizedBox(height: 20),

                  // Routing Stops Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.shade50.withOpacity(0.5), border: Border.all(color: Colors.red.shade100), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MANUAL ROUTING STOPS', style: TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        ...List.generate(_stops.length, (index) => _buildRoutingStop(index + 1, _stops[index])),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => setState(() => _stops.add('New Office')),
                          child: Row(children: const [Icon(Icons.add_circle_outline, color: AppTheme.primaryRed, size: 16), SizedBox(width: 8), Text('Add Custom Stop', style: TextStyle(color: AppTheme.primaryRed, fontSize: 13, fontWeight: FontWeight.bold))])
                        )
                      ]
                    )
                  ),
                  const SizedBox(height: 20),
                  
                  // Estimated Completion
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('EST. COMPLETION', style: TextStyle(color: Color(0xFF902020), fontSize: 10, fontWeight: FontWeight.bold)), Text(_getEstimatedDate(), style: const TextStyle(color: Color(0xFF902020), fontWeight: FontWeight.bold, fontSize: 13))])),
                  const SizedBox(height: 20),
                  
                  // Verification
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 24, height: 24, child: Checkbox(value: _isVerified, activeColor: AppTheme.primaryRed, side: BorderSide(color: Colors.grey.shade400), onChanged: (value) { setState(() { _isVerified = value ?? false; }); })), const SizedBox(width: 12), const Expanded(child: Text('I verify that all attached information is accurate and follows institutional guidelines.', style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4)))])
                ],
              ),
            ),
          ),
          Divider(color: Colors.red.shade100, height: 1),
          Padding(
            padding: const EdgeInsets.all(20.0), 
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)))), 
              const SizedBox(width: 16), 
              
              // Animated Submit Button
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDocument, 
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                  child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
                )
              )
            ])
          )
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(padding: const EdgeInsets.all(20.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('New Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.black54))]));
  
  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54));
  
  Widget _buildTextField(String hint) => TextField(controller: _titleController, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade100)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryRed)), filled: true, fillColor: const Color(0xFFFFF9F9)));
  
  // Converted to an actual functional Dropdown using your existing design
  Widget _buildDropdown(String hint) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
    decoration: BoxDecoration(color: const Color(0xFFFFF9F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)), 
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        isExpanded: true,
        hint: Text(hint, style: const TextStyle(color: Colors.black87)),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
        value: _selectedProcessId,
        items: _processTypes.map<DropdownMenuItem<int>>((dynamic process) {
          return DropdownMenuItem<int>(
            value: process['p_id'],
            child: Text(process['process_name'], overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (int? val) => setState(() => _selectedProcessId = val),
      )
    )
  );
  
  Widget _buildRoutingStop(int number, String label) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), child: Row(children: [CircleAvatar(radius: 12, backgroundColor: AppTheme.primaryRed, child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 16), Expanded(child: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 13))), const Icon(Icons.delete_outline, color: Colors.black54, size: 18)]));
}