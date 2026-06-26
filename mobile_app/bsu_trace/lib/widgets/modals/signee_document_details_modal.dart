// lib/widgets/modals/signee_document_details_modal.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'signee_send_back_modal.dart';
import 'signee_ad_hoc_routing_modal.dart';

class SigneeDocumentDetailsModal extends StatelessWidget {
  const SigneeDocumentDetailsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFFDFD), // Very soft warm white/pinkish
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- DRAG HANDLE ---
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- HEADER ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ID: BSU-2024-0891',
                        style: TextStyle(
                          color: AppTheme.primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Faculty Research Grant Application',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- INFO CARDS ---
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard('FORM TYPE', 'Academic Affairs'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard('ORIGIN OFFICE', 'Research Office'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRequestorCard('Dr. Elena Reyes', 'UR'),
            const SizedBox(height: 32),

            // --- PROCESSING ROUTE ---
            const Text(
              'PROCESSING ROUTE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildTimelineStep(
              dotColor: Colors.green,
              hasOuterRing: false,
              lineColor: Colors.grey.shade300,
              title: 'Department Head Approval',
              titleColor: Colors.black87,
              subtitle: 'Completed • Oct 10, 09:30 AM',
              isLast: false,
            ),
            _buildTimelineStep(
              dotColor: AppTheme.primaryRed,
              hasOuterRing: true,
              lineColor: Colors.grey.shade300,
              title: 'University Registrar (Current)',
              titleColor: AppTheme.primaryRed,
              subtitle: 'Pending your action',
              isLast: false,
            ),
            _buildTimelineStep(
              dotColor: Colors.red.shade100,
              hasOuterRing: false,
              lineColor: Colors.transparent,
              title: 'Vice President for Academic Affairs',
              titleColor: Colors.black38,
              subtitle: 'Next in queue',
              isLast: true,
            ),
            
            const SizedBox(height: 8),
            Divider(color: Colors.red.shade100, thickness: 1),
            const SizedBox(height: 20),

            // --- ACTION BUTTONS ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const SigneeAdHocRoutingModal(),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Ad-hoc Routing', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const SigneeSendBackModal(),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Send Back', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Sign Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for the square info cards
  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // Helper for the requestor banner
  Widget _buildRequestorCard(String name, String initials) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REQUESTOR',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.red.shade200,
                child: Text(
                  initials,
                  style: const TextStyle(fontSize: 10, color: AppTheme.primaryRed, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper for the visual timeline list
  Widget _buildTimelineStep({
    required Color dotColor,
    required bool hasOuterRing,
    required Color lineColor,
    required String title,
    required Color titleColor,
    required String subtitle,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphic Column (Dot and Line)
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasOuterRing ? Colors.white : dotColor,
                  border: hasOuterRing ? Border.all(color: Colors.red.shade100, width: 3) : null,
                ),
                child: hasOuterRing
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                          ),
                        ),
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: lineColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isLast ? Colors.black38 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}