import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/admin_document_details_modal.dart';
import '../../widgets/modals/document_scanner_modal.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GSO Admin'), actions: buildAppBarActions(context)),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- 1. Institutional Profile Card ---
            _buildProfileCard(),
            const SizedBox(height: 20),

            // --- 2. Dashboard Metrics ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalDocumentsCard(),
                const SizedBox(width: 12),
                _buildSmallMetricsGrid(),
              ],
            ),
            const SizedBox(height: 20),

            // --- 3. Recent Documents Table ---
            _buildRecentDocumentsTable(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // UPDATED LOGIC TO SHOW THE SCANNER MODAL
          showDialog(
            context: context,
            builder: (context) => const DocumentScannerModal(),
          );
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.document_scanner_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INSTITUTIONAL PROFILE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryRed, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          const Text('Admin User', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.person_outline, size: 16, color: Colors.grey), const SizedBox(width: 6), const Text('GSO Administrator', style: TextStyle(color: Colors.grey))]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.location_city, size: 16, color: Colors.grey), const SizedBox(width: 6), const Text('General Services Office', style: TextStyle(color: Colors.grey))]),
        ],
      ),
    );
  }

  Widget _buildTotalDocumentsCard() {
    return Expanded(
      flex: 1,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, color: Colors.white, size: 40),
            const SizedBox(height: 16),
            const Text('245', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const Text('TOTAL DOCUMENTS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallMetricsGrid() {
    return Expanded(
      flex: 1,
      child: Column(
        children: [
          Row(children: [_buildMetric('15', 'INCOMING', Icons.downloading, Colors.blue.shade100), const SizedBox(width: 12), _buildMetric('28', 'PENDING', Icons.assignment_late, Colors.orange.shade100)]),
          const SizedBox(height: 12),
          Row(children: [_buildMetric('42', 'ARCHIVED', Icons.archive, Colors.grey.shade200), const SizedBox(width: 12), _buildMetric('160', 'COMPLETED', Icons.check_circle, Colors.green.shade100)]),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label, IconData icon, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade50)),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDocumentsTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Recent Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Text('VIEW ALL', style: TextStyle(color: AppTheme.primaryRed, fontSize: 12, fontWeight: FontWeight.bold))]),
          ),
          Container(padding: const EdgeInsets.all(16), color: Colors.red.shade50, child: Row(children: const [Expanded(child: Text('TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))), Expanded(child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))), Expanded(child: Text('ACTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))])),
          _buildDocRow(context, 'Annual Procure...', 'PENDING'),
          _buildDocRow(context, 'Property Receipt', 'SIGNED'),
          
          // Pagination
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chevron_left, size: 20),
                const SizedBox(width: 16),
                Container(width: 24, height: 24, decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle), child: const Center(child: Text('1', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 16),
                const Text('2', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                const Text('3', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDocRow(BuildContext context, String title, String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.red.shade50))),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Text('APP-2024-001', style: TextStyle(fontSize: 10, color: Colors.grey))])),
          Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: status == 'PENDING' ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(4)), child: Text(status, textAlign: TextAlign.center, style: TextStyle(color: status == 'PENDING' ? Colors.orange : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)))),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const DocumentDetailsModal(),
                  );
                },
                child: const Icon(Icons.remove_red_eye_outlined, color: AppTheme.primaryRed, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}