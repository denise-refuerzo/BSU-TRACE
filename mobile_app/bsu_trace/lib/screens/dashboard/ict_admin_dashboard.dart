import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar_helper.dart';
import '../../../widgets/app_drawer.dart';
import '../../services/session_manager.dart';
import '../../models/user_role.dart';

class IctAdminDashboardScreen extends StatelessWidget {
  const IctAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // GATEKEEPER (Ensure you add UserRole.ictAdmin to your enum!)
    
    final role = SessionManager().currentRole;
    if (role != UserRole.ictAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    

    return Scaffold(
      appBar: AppBar(
        title: const Text('ICT Admin'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildStatCard('Total Users', '342', Icons.people_outline, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('Active Now', '48', Icons.online_prediction, Colors.green),
              ],
            ),
            const SizedBox(height: 20),
            _buildPlaceholderMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SYSTEM ADMINISTRATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryRed, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          const Text('System ICT Administrator', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: const [
            Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.grey),
            SizedBox(width: 6),
            Text('Super Admin Access', style: TextStyle(color: Colors.grey))
          ]),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade50),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100, style: BorderStyle.solid),
      ),
      child: Column(
        children: const [
          Icon(Icons.dashboard_customize_outlined, size: 48, color: AppTheme.primaryRed),
          SizedBox(height: 16),
          Text(
            'Dashboard Coming Soon',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
          ),
          SizedBox(height: 8),
          Text(
            'System logs, API health, and recent login activities will be displayed here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}