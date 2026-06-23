import 'package:flutter/material.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/new_document_modal.dart';

class UserDashboardScreen extends StatelessWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BSU Portal (User)'), 
        actions: buildAppBarActions(context)
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Institutional Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: const [Icon(Icons.person_outline, size: 16, color: Colors.black54), SizedBox(width: 4), Text('John Doe', style: TextStyle(color: Colors.black54))]),
                    const SizedBox(height: 4),
                    Row(children: const [Icon(Icons.work_outline, size: 16, color: Colors.black54), SizedBox(width: 4), Text('Faculty • Academic Department', style: TextStyle(color: Colors.black54, fontSize: 12))]),
                  ],
                ),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance, color: Color(0xFFB01A22), size: 32))
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildStatCard('TOTAL DOCS', '1,284', Icons.folder_open, const Color(0xFFB01A22)),
                _buildStatCard('PENDING', '12', Icons.pending_actions, const Color(0xFFB01A22)),
                _buildStatCard('ARCHIVED', '450', Icons.archive_outlined, Colors.blueGrey),
                _buildStatCard('COMPLETED', '822', Icons.check_circle_outline, Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Submission Flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildHorizontalStepper(),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFFF9F9), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Current: Waiting for Department Head approval on "Quarterly Report Q3".', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54, fontSize: 13)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
            floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const NewDocumentModal(),
          );
        },
        backgroundColor: const Color(0xFFB01A22),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [Icon(icon, color: iconColor, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHorizontalStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepNode('Draft', isActive: true, isCompleted: true),
        Expanded(child: Container(height: 4, color: const Color(0xFFB01A22))),
        _buildStepNode('Review', isActive: true, isCurrent: true),
        Expanded(child: Container(height: 4, color: Colors.grey.shade300)),
        _buildStepNode('Approval', isActive: false),
        Expanded(child: Container(height: 4, color: Colors.grey.shade300)),
        _buildStepNode('Finalized', isActive: false),
      ],
    );
  }

  Widget _buildStepNode(String label, {bool isActive = false, bool isCompleted = false, bool isCurrent = false}) {
    return Column(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFFB01A22) : (isActive ? Colors.red.shade100 : Colors.grey.shade300),
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: const Color(0xFFB01A22), width: 3) : null,
          ),
          child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFFB01A22) : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}

// Bottom Sheet Component
class NewDocumentBottomSheet extends StatelessWidget {
  const NewDocumentBottomSheet({super.key});
  
  @override
  Widget build(BuildContext context) {
    // Paste your existing NewDocumentBottomSheet logic here if you want to keep it in this file
    // Or you can create a new file in lib/widgets/modals/new_document_bottom_sheet.dart
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: const Text('Add your Bottom Sheet contents here'),
    );
  }
}