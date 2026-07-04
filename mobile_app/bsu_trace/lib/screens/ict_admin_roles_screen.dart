import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';

class IctAdminRolesScreen extends StatelessWidget {
  const IctAdminRolesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Roles',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'View and configure permission sets mapped to account types.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _buildRoleList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Add new role implementation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add role feature coming soon!')),
          );
        },
        backgroundColor: AppTheme.primaryRed,
        icon: const Icon(Icons.security, color: Colors.white),
        label: const Text('Add Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRoleList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          _buildRoleItem('Originator', 'Standard users who create documents and bookings.', Icons.edit_document),
          const Divider(height: 1, color: Color(0xFFFFEBEE)), // Colors.red.shade50
          _buildRoleItem('Processor', 'Verifies documents along the routing path.', Icons.verified_user_outlined),
          const Divider(height: 1, color: Color(0xFFFFEBEE)),
          _buildRoleItem('Signee', 'Approves or rejects documents (e.g., Deans, Heads).', Icons.draw_outlined),
          const Divider(height: 1, color: Color(0xFFFFEBEE)),
          _buildRoleItem('GSO Admin', 'Manages physical resources, vehicles, and facilities.', Icons.domain),
          const Divider(height: 1, color: Color(0xFFFFEBEE)),
          _buildRoleItem('ICT Admin', 'Full system access, manages users and roles.', Icons.admin_panel_settings, isPrimary: true),
        ],
      ),
    );
  }

  Widget _buildRoleItem(String title, String description, IconData icon, {bool isPrimary = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primaryRed : Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : AppTheme.primaryRed,
          size: 24,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        // TODO: Navigate to Role detail page
      },
    );
  }
}