// lib/widgets/modals/document_scanner_modal.dart
import 'dart:convert'; // Added to decode the backend error message
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../config.dart';

class DocumentScannerModal extends StatefulWidget {
  const DocumentScannerModal({super.key});

  @override
  State<DocumentScannerModal> createState() => _DocumentScannerModalState();
}

class _DocumentScannerModalState extends State<DocumentScannerModal> {
  final TextEditingController _trackingIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _processScan(String action) async {
    final trackingId = _trackingIdController.text.trim();
    
    if (trackingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Tracking ID.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final endpoint = action == 'in' ? 'scan-in' : 'scan-out';
      final response = await http.put(Uri.parse('${AppConfig.baseUrl}/documents/$trackingId/$endpoint'));

      if (response.statusCode == 200) {
        if (!mounted) return;
        
        // Pass 'true' back to the parent screen to trigger a refresh
        Navigator.pop(context, true); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document $trackingId successfully scanned ${action.toUpperCase()}!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        // Parse custom error message from the backend
        String errorMessage = 'Error: Could not process document.';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          }
        } catch (_) {}
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      
      // Clean up the error message for the user interface
      String displayError = e.toString().replaceAll('Exception: ', '');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4), // Give them time to read the reason
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _trackingIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan Document',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- CAMERA PLACEHOLDER ---
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black87, // Dark background to simulate camera
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Viewfinder border simulation
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white.withOpacity(0.7), size: 50),
                      const SizedBox(height: 12),
                      Text(
                        'Camera Placeholder\n(Point at QR Code)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            const Center(
              child: Text(
                'OR enter manually:',
                style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            
            // Tracking ID Input
            TextField(
              controller: _trackingIdController,
              decoration: InputDecoration(
                labelText: 'Tracking ID',
                hintText: 'e.g. TRK-171829...',
                prefixIcon: const Icon(Icons.qr_code, color: Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryRed)),
              ),
            ),
            const SizedBox(height: 24),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _processScan('in'),
                      icon: const Icon(Icons.login, color: Colors.white, size: 18),
                      label: const Text('Scan IN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _processScan('out'),
                      icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                      label: const Text('Scan OUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}