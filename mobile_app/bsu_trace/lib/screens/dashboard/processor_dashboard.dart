import 'package:flutter/material.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/modals/document_scanner_modal.dart';
// Add these imports
import '../../services/session_manager.dart';
import '../../models/user_role.dart';

class ProcessorDashboardScreen extends StatelessWidget {
  const ProcessorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // GATEKEEPER
    final role = SessionManager().currentRole;
    if (role != UserRole.processor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCF6F6),
      appBar: AppBar(
        title: const Text('BSU Portal (Processor)'), 
        actions: buildAppBarActions(context)
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hello, Processor', style: TextStyle(color: Colors.black54)),
            const Text('Document Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildStatCard('15', 'INCOMING DOCS', Colors.white, Colors.red.shade100),
                const SizedBox(width: 12),
                _buildStatCard('28', 'PENDING APPROVAL', Colors.white, Colors.orange.shade100),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard('160', 'COMPLETED', Colors.white, Colors.green.shade100, isFullWidth: true),
            const SizedBox(height: 24),
            const Text('Current Priority', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPriorityCard(),
            const SizedBox(height: 24),
            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildActivityItem('Scholarship App #102', 'OSAS • 10:45 AM', 'Approved', Colors.green),
            _buildActivityItem('Leave Request - Prof. Lim', 'HR Office • Yesterday', 'Pending', Colors.orange),
            _buildActivityItem('Research Proposal Draft', 'Grad School • Yesterday', 'In Review', AppTheme.primaryRed),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const DocumentScannerModal(),
          );
        },
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard(String count, String label, Color bgColor, Color borderColor, {bool isFullWidth = false}) {
    return Expanded(
      flex: isFullWidth ? 0 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transcript of Records #8821', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)), child: const Text('IN PROGRESS', style: TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold)))
            ],
          ),
          const SizedBox(height: 4),
          const Text('Registrar\'s Office • High Priority', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStepNode(true, 'Submission'),
              _buildConnector(true),
              _buildStepNode(true, 'Verification'),
              _buildConnector(false),
              _buildStepNode(false, 'Approval'),
              _buildConnector(false),
              _buildStepNode(false, 'Dispatch'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStepNode(bool isActive, String label) {
    return Column(children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(color: isActive ? AppTheme.primaryRed : Colors.grey.shade200, shape: BoxShape.circle), child: isActive ? const Icon(Icons.check, color: Colors.white, size: 14) : null),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 9, color: isActive ? AppTheme.primaryRed : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal))
    ]);
  }

  Widget _buildConnector(bool isActive) => Expanded(child: Container(height: 2, color: isActive ? AppTheme.primaryRed : Colors.grey.shade200, margin: const EdgeInsets.only(bottom: 15)));

  Widget _buildActivityItem(String title, String subtitle, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade50)),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: AppTheme.primaryRed.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
          Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12))
        ],
      ),
    );
  }
}