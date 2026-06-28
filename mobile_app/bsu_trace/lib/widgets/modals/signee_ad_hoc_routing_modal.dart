// lib/widgets/modals/signee_ad_hoc_routing_modal.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../config.dart';

class SigneeAdHocRoutingModal extends StatefulWidget {
  final Map<String, dynamic> document;

  const SigneeAdHocRoutingModal({super.key, required this.document});

  @override
  State<SigneeAdHocRoutingModal> createState() => _SigneeAdHocRoutingModalState();
}

class _SigneeAdHocRoutingModalState extends State<SigneeAdHocRoutingModal> {
  List<dynamic> _offices = [];
  String? _selectedOfficeId;
  final TextEditingController _reasonController = TextEditingController();
  
  bool _isLoadingOffices = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchOffices();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchOffices() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/offices'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _offices = json.decode(response.body);
            _isLoadingOffices = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingOffices = false);
      debugPrint("Error fetching offices: $e");
    }
  }

  Future<void> _submitAdHocRouting() async {
    if (_selectedOfficeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target office.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final String qrCode = widget.document['qr_code'];

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/documents/$qrCode/ad-hoc'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'target_office_id': int.parse(_selectedOfficeId!),
          'reason': _reasonController.text.trim()
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true); 
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document routed successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to route document');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Failed to route document.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFFDFD), 
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: AppTheme.primaryRed),
                ),
                const SizedBox(width: 16),
                const Text('Ad-hoc Routing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Route ${widget.document['qr_code']} to an office not in the standard workflow.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            const Text('Target Office', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: _isLoadingOffices 
                  ? const Padding(padding: EdgeInsets.all(8.0), child: Text('Loading offices...', style: TextStyle(color: Colors.grey)))
                  : DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedOfficeId,
                      hint: const Text('Select Office...', style: TextStyle(fontSize: 14, color: Colors.black87)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      items: _offices.map<DropdownMenuItem<String>>((office) {
                        return DropdownMenuItem<String>(
                          value: office['o_id'].toString(),
                          child: Text(office['office_name'], style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedOfficeId = value),
                    ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Reason for Routing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                filled: true,
                fillColor: Colors.red.shade50.withValues(alpha: 0.5),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryRed),
                ),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAdHocRouting,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isSubmitting 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Forward Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}