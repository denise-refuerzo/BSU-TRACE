// lib/widgets/modals/signee_history_details_modal.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SigneeHistoryDetailsModal extends StatelessWidget {
  const SigneeHistoryDetailsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent, // Let ClipRRect handle corners
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- HEADER ---
              Container(
                color: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Document Detail Log',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'REFERENCE ID: #SIGN-2024-0612',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),

              // --- SCROLLABLE BODY ---
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- CUSTOM HORIZONTAL STEPPER ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepNode('DRAFTED', isCompleted: true),
                          _buildConnector(isCompleted: true),
                          _buildStepNode('PROCESSED', isCompleted: true),
                          _buildConnector(isCompleted: true),
                          _buildStepNode('AD-HOC', isCurrent: true),
                          _buildConnector(isCompleted: false),
                          _buildStepNode('FINAL SIGN', number: '4'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Divider(color: Colors.grey.shade100, thickness: 1, height: 1),
                      const SizedBox(height: 24),

                      // --- INFO GRID ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInfo('TITLE', 'Curriculum Revision\nRequest #402'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfo('FORM TYPE', 'Academic Form -\nRevision Type A'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInfo(
                              'CURRENT STATUS',
                              'Pending Ad-hoc\nApproval',
                              valueColor: AppTheme.primaryRed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfo('PROCESSOR NAME', 'Dr. Helena Vance'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInfo('TIME IN', 'Jun 12, 2024 - 09:42\nAM'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfo('AD-HOC OFFICE', 'Dean of Faculty\nCouncil'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildInfo('SIGNEE NAME', 'Prof. Marcus Sterling'),
                      const SizedBox(height: 24),

                      // --- RETURN NOTE BOX ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.assignment_return_outlined, size: 16, color: AppTheme.primaryRed),
                                SizedBox(width: 8),
                                Text(
                                  'RETURN NOTE / REMARKS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryRed,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'The course syllabus attached is missing the updated laboratory safety guidelines mandated for the 2024 academic year. Please revise Section 4.2 to include the new hazardous materials handling protocols and resubmit for department-level review. Ensure all faculty signatures are present on the amendment page.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- FOOTER BUTTONS ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                color: Colors.red.shade50.withOpacity(0.5), // Light pink tint
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: Colors.white,
                        ),
                        child: const Text('Close', style: TextStyle(color: Colors.black87, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle Print Log logic
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Print Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _buildStepNode(String label, {bool isCompleted = false, bool isCurrent = false, String? number}) {
    Color primary = AppTheme.primaryRed;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted ? primary : (isCurrent ? Colors.white : Colors.red.shade100),
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: primary, width: 2) : null,
          ),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : (isCurrent
                  ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: primary, shape: BoxShape.circle)))
                  : Center(child: Text(number ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isCompleted || isCurrent ? primary : Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector({required bool isCompleted}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 14), // Align with the center of the 28px circle
        height: 3,
        color: isCompleted ? AppTheme.primaryRed : Colors.red.shade100,
      ),
    );
  }

  Widget _buildInfo(String label, String value, {Color valueColor = Colors.black87}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: 14, color: valueColor, height: 1.3),
        ),
      ],
    );
  }
}