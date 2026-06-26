import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class DocumentScannerModal extends StatelessWidget {
  const DocumentScannerModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- HEADER ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                color: AppTheme.primaryRed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan Document QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    )
                  ],
                ),
              ),

              // --- SCANNER VIEWFINDER (MOCK) ---
              Container(
                padding: const EdgeInsets.all(24),
                color: const Color(0xFF1A1A1A), // Dark background for camera feel
                child: Column(
                  children: [
                    const Text(
                      'Align QR code within the frame to track or update status.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    
                    // Viewfinder Frame
                    Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryRed, width: 3),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withOpacity(0.05), // Slight transparent fill
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Scanning Line Animation (Static representation)
                          Positioned(
                            top: 90, // Middle of the box
                            child: Container(
                              width: 180,
                              height: 2,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRed,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryRed.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          ),
                          const Icon(Icons.qr_code_scanner, color: Colors.white24, size: 80),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // --- MANUAL ENTRY FALLBACK ---
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    const Text(
                      'Enter Tracking Number',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'e.g. BSU-2023-TR-8842',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        prefixIcon: const Icon(Icons.keyboard, color: Colors.black54),
                        filled: true,
                        fillColor: AppTheme.scaffoldBg,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.primaryRed),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: () {
                        // Handle manual search logic
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Track Document',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}