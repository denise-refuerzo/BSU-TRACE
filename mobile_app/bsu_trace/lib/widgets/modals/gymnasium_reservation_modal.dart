import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class GymnasiumReservationModal extends StatefulWidget {
  const GymnasiumReservationModal({super.key});

  @override
  State<GymnasiumReservationModal> createState() => _GymnasiumReservationModalState();
}

class _GymnasiumReservationModalState extends State<GymnasiumReservationModal> {
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
      backgroundColor: Colors.transparent, 
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
                            'Gymnasium Reservation', 
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Georgia', // Serif font matches screen title
                            )
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Court #1 (SCREEN_46 Reference)', 
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
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
                          child: _buildInfo('DATE & TIME', 'Dec 10, 2023 |\n04:00 PM - 07:00\nPM')
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

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
                              Icon(Icons.assignment_outlined, size: 16, color: Colors.black54),
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

              // --- DIVIDER ---
              Divider(height: 1, color: Colors.red.shade100, thickness: 1),

              // --- FOOTER BUTTONS (TINTED BACKGROUND) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                color: Colors.red.shade50.withValues(alpha: 0.5), // Light pink footer
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context), 
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryRed), 
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                        ), 
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12))
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAllChecked ? () {
                          // Handle confirmation logic here
                          Navigator.pop(context);
                        } : null, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isAllChecked ? AppTheme.primaryRed : Colors.grey.shade200,
                          disabledBackgroundColor: Colors.grey.shade200, 
                          disabledForegroundColor: Colors.grey.shade400,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                        ), 
                        child: Text(
                          'Confirm Reservation', 
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isAllChecked ? Colors.white : Colors.grey.shade400, 
                            fontSize: 11, 
                            fontWeight: FontWeight.bold
                          )
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
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold, letterSpacing: 0.5)), 
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87, height: 1.4)),
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
              side: BorderSide(color: Colors.grey.shade400, width: 1.5), 
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