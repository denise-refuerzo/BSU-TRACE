import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/signee_document_details_modal.dart';
// Add these imports
import '../../services/session_manager.dart';
import '../../models/user_role.dart';

class SigneeDashboardScreen extends StatelessWidget {
  const SigneeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // GATEKEEPER
    final role = SessionManager().currentRole;
    if (role != UserRole.signee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Signee Dashboard'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('PENDING', '12', Icons.pending_actions, Colors.red.shade50, AppTheme.primaryRed, valueColor: AppTheme.primaryRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('SIGNED', '148', Icons.draw_outlined, Colors.blue.shade50, Colors.blue.shade700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('VERIFICATION', '05', Icons.shield_outlined, Colors.grey.shade200, Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('SENT BACK', '02', Icons.assignment_return_outlined, Colors.red.shade50, AppTheme.primaryRed, valueColor: AppTheme.primaryRed),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildEfficiencyChart(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Documents Pending',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: Colors.black87),
                ),
                Row(
                  children: const [
                    Text('View All', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: AppTheme.primaryRed, size: 16),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDocCard(
              context: context,
              title: 'Strategic Plan FY2024',
              id: 'BSU-24-9011',
              formType: 'Administrative Memo',
              office: "Chancellor's Office",
              icon: Icons.description_outlined,
            ),
            _buildDocCard(
              context: context,
              title: 'Procurement Requisition',
              id: 'BSU-24-8842',
              formType: 'Purchase Order',
              office: 'Finance & Logistics',
              icon: Icons.receipt_long_outlined,
            ),
            const SizedBox(height: 24),
            const Text(
              'System Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _buildSystemStatus(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconBg, Color iconColor, {Color valueColor = Colors.black87}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: valueColor, height: 1),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(4)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('Efficiency Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia')),
              SizedBox(width: 12),
              Text('2.4', style: TextStyle(color: AppTheme.primaryRed, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 4),
              Text('Avg Hours', style: TextStyle(color: Colors.black54, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildChartBar('M', 40, false),
                _buildChartBar('T', 60, false),
                _buildChartBar('W', 100, true),
                _buildChartBar('T', 50, false),
                _buildChartBar('F', 0, false),
                _buildChartBar('S', 20, false),
                _buildChartBar('S', 15, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(String day, double heightPct, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (heightPct > 0)
          Container(
            width: 32,
            height: (heightPct / 100) * 70,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryRed : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? AppTheme.primaryRed : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDocCard({
    required BuildContext context, 
    required String title, 
    required String id, 
    required String formType, 
    required String office, 
    required IconData icon
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: AppTheme.primaryRed),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('ID: $id', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const SigneeDocumentDetailsModal(),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.remove_red_eye_outlined, color: AppTheme.primaryRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FORM TYPE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(formType, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OFFICE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(office, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          _buildStatusRow(Icons.lock_outline, 'Digital Seal', 'Active', isGreen: true),
          Divider(height: 1, color: Colors.red.shade100),
          _buildStatusRow(Icons.cloud_queue, 'Cloud Storage', 'Connected', isGreen: true),
          Divider(height: 1, color: Colors.red.shade100),
          _buildStatusRow(Icons.sync_alt, 'Audit Sync', 'Last: 2m ago', isGreen: false),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String title, String status, {required bool isGreen}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.black87, fontSize: 14))),
          if (isGreen)
            Container(
              margin: const EdgeInsets.only(right: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
            ),
          Text(
            status,
            style: TextStyle(
              color: isGreen ? Colors.teal : Colors.black54,
              fontSize: 12,
              fontWeight: isGreen ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}