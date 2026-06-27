import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MultimediaReservationModal extends StatefulWidget {
  const MultimediaReservationModal({super.key});

  @override
  State<MultimediaReservationModal> createState() => _MultimediaReservationModalState();
}

class _MultimediaReservationModalState extends State<MultimediaReservationModal> {
  // Checklist State
  bool _formChecked = false;
  bool _intentChecked = false;
  bool _idChecked = false;
  bool _clearanceChecked = false;

  // Helper to check if all documents are verified
  bool get _isAllChecked => _formChecked && _intentChecked && _idChecked && _clearanceChecked;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.transparent, // Transparent to let ClipRRect handle corners
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- RED HEADER ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                color: AppTheme.primaryRed,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Multimedia Reservation', 
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Room #104 (AV Reference)', 
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context), 
                      child: const Icon(Icons.close, color: Colors.white, size: 24)
                    )
                  ],
                ),
              ),
              
              // --- BODY SECTION ---
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildInfo('REQUESTOR', 'Varsity Sports\nCouncil')
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfo('DATE & TIME', 'Dec 10, 2023 |\n04:00 PM -\n07:00 PM')
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(height: 1, color: Colors.grey.shade200, thickness: 1),
                    const SizedBox(height: 20),

                    // --- CHECKLIST SECTION ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50.withValues(alpha: 0.5), 
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade100)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.fact_check_outlined, size: 18, color: AppTheme.primaryRed),
                              SizedBox(width: 8),
                              Text(
                                'DOCUMENT CHECKLIST', 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54, letterSpacing: 0.5)
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCheckboxRow('Approved Request Form', _formChecked, (v) => setState(() => _formChecked = v!)),
                          _buildCheckboxRow('Letter of Intent', _intentChecked, (v) => setState(() => _intentChecked = v!)),
                          _buildCheckboxRow('Student/Faculty ID\nPhotocopy', _idChecked, (v) => setState(() => _idChecked = v!)),
                          _buildCheckboxRow('Facility Clearance Slip', _clearanceChecked, (v) => setState(() => _clearanceChecked = v!)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- FOOTER BUTTONS (TINTED BACKGROUND) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                color: Colors.red.shade50, // Matches the light pink footer background
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context), 
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryRed), 
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ), 
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAllChecked ? () {
                          // Handle confirmation logic here
                          Navigator.pop(context);
                        } : null, 
                        style: ElevatedButton.styleFrom(
                          // Uses a faded red when disabled, full red when enabled
                          backgroundColor: _isAllChecked ? AppTheme.primaryRed : const Color(0xFFD67272),
                          disabledBackgroundColor: const Color(0xFFD67272), 
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ), 
                        child: const Text(
                          'Confirm Reservation', 
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                        )
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

  // --- REUSABLE WIDGETS ---

  Widget _buildInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold, letterSpacing: 0.5)), 
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87, height: 1.4)),
      ]
    );
  }
  
  Widget _buildCheckboxRow(String label, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryRed,
              side: BorderSide(color: Colors.red.shade200, width: 1.5), // Pinkish tint for unchecked box
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}