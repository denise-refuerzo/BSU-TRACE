// lib/screens/signee_pending_approvals_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/signee_document_details_modal.dart';

class SigneePendingApprovalsScreen extends StatelessWidget {
  const SigneePendingApprovalsScreen({super.key});

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
              'Documents',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by title or ID...',
                hintStyle: const TextStyle(color: Colors.black54),
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
              style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)
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
            
            // Document Cards
            _buildDocCard(
              context: context,
              id: 'BSU-2024-0891',
              title: 'Faculty Research Grant Application',
              formType: 'ACADEMIC AFFAIRS',
              status: 'Pending Review',
              date: 'Oct 12, 2023',
              statusColor: Colors.orange,
            ),
            _buildDocCard(
              context: context,
              id: 'BSU-2024-0722',
              title: 'Quarterly Budget Realignment',
              formType: 'FINANCE',
              status: 'In Verification',
              date: 'Oct 10, 2023',
              statusColor: Colors.blueAccent,
            ),
            _buildDocCard(
              context: context,
              id: 'BSU-2024-0615',
              title: 'Student Scholarship Endorsement',
              formType: 'STUDENT SERVICES',
              status: 'Signed',
              date: 'Oct 05, 2023',
              statusColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard({
    required BuildContext context,
    required String id,
    required String title,
    required String formType,
    required String status,
    required String date,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: ID and Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ID: $id',
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const SigneeDocumentDetailsModal(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove_red_eye_outlined,
                    color: AppTheme.primaryRed,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          
          // Form Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'FORM: $formType',
              style: const TextStyle(
                color: AppTheme.primaryRed,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Bottom Row: Status and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}