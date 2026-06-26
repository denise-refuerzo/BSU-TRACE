// lib/screens/signee_signature_history_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/signee_history_details_modal.dart'; // Modal imported here

class SigneeSignatureHistoryScreen extends StatelessWidget {
  const SigneeSignatureHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Office Signee'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Processing History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Track the progress of your submitted\ndocuments.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 24),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by title or ID...',
                hintStyle: const TextStyle(color: Colors.black38),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade100),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryRed),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filter Dropdown
            const Text(
              'Filter by Status',
              style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: 'All Statuses',
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                  items: const [
                    DropdownMenuItem(value: 'All Statuses', child: Text('All Statuses')),
                  ],
                  onChanged: (value) {},
                ),
              ),
            ),
            const SizedBox(height: 24),

            // History Cards
            _buildHistoryCard(
              context: context, // Pass context for the modal
              tag: 'ACADEMIC FORM',
              date: 'Jun 12, 2024',
              title: 'Curriculum Revision Request #402',
              office: 'Applied Arts Dept',
              status: 'COMPLETED',
              statusColor: const Color(0xFF00BFA5), // Greenish/Teal
            ),
            _buildHistoryCard(
              context: context, // Pass context for the modal
              tag: 'ADMINISTRATIVE',
              date: 'Jun 10, 2024',
              title: 'Office Equipment Procurement',
              office: 'BSU Faculty Office',
              status: 'PENDING AD-HOC',
              statusColor: Colors.orangeAccent,
            ),
            _buildHistoryCard(
              context: context, // Pass context for the modal
              tag: 'RESEARCH',
              date: 'Jun 08, 2024',
              title: 'Grant Proposal Phase II',
              office: 'Research & Innovation',
              status: 'IN REVIEW',
              statusColor: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }

  // Method updated to require BuildContext to handle routing to the dialog
  Widget _buildHistoryCard({
    required BuildContext context,
    required String tag,
    required String date,
    required String title,
    required String office,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Tag and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // Office
          Row(
            children: [
              const Icon(Icons.domain, size: 14, color: Colors.black38),
              const SizedBox(width: 8),
              Text(
                office,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bottom Row: Status and Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              // Wrapped in GestureDetector to trigger the Detail Log Modal
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const SigneeHistoryDetailsModal(),
                  );
                },
                child: Row(
                  children: const [
                    Text(
                      'View Details',
                      style: TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: AppTheme.primaryRed,
                      size: 16,
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}