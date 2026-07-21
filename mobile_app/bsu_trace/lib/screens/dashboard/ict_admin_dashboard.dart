import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import '../../services/session_manager.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/add_user_modal.dart';
import '../ict_admin_accounts_screen.dart';
import '../ict_admin_roles_screen.dart';

class IctAdminDashboard extends StatefulWidget {
  const IctAdminDashboard({Key? key}) : super(key: key);

  @override
  State<IctAdminDashboard> createState() => _IctAdminDashboardState();
}

class _IctAdminDashboardState extends State<IctAdminDashboard> {
  bool _isLoading = true;
  String _adminName = 'System Administrator';
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalOffices = 0;
  int _totalSystemLogs = 0;
  List<dynamic> _recentUsers = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // Use your singleton SessionManager
      final session = SessionManager();
      final token = session.sessionToken;
      final userId = session.userId;

      if (token == null || userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // AppConfig.baseUrl already includes '/api', so we append '/admin/ict-stats'
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/ict-stats?u_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data['adminName'] != null) {
            _adminName = data['adminName'];
          }
          _totalUsers = data['totalUsers'] ?? 0;
          _activeUsers = data['activeUsers'] ?? 0;
          _totalOffices = data['totalOffices'] ?? 0;
          _totalSystemLogs = data['totalSystemLogs'] ?? 0;
          _recentUsers = data['recentUsers'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching ICT Admin stats: $e');
      setState(() => _isLoading = false);
    }
  }

  void _openAddUserModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddUserModal(),
    ).then((updated) {
      if (updated == true) {
        _loadDashboardData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar (title: const Text('ICT Admin Dashboard')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddUserModal,
        backgroundColor: const Color(0xFF800000),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add User', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Banner
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: const Color(0xFF800000),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.admin_panel_settings,
                                  size: 32, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, $_adminName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'System Infrastructure & Access Control',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Metrics Grid
                    const Text(
                      'System Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      childAspectRatio: 1.4,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          title: 'Total Users',
                          value: '$_totalUsers',
                          icon: Icons.people,
                          color: Colors.blue.shade700,
                        ),
                        _buildStatCard(
                          title: 'Active Accounts',
                          value: '$_activeUsers',
                          icon: Icons.check_circle,
                          color: Colors.green.shade700,
                        ),
                        _buildStatCard(
                          title: 'System Offices',
                          value: '$_totalOffices',
                          icon: Icons.business,
                          color: Colors.orange.shade700,
                        ),
                        _buildStatCard(
                          title: 'Audit Logs',
                          value: '$_totalSystemLogs',
                          icon: Icons.history,
                          color: Colors.purple.shade700,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text(
                      'Management Console',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.manage_accounts,
                            color: Color(0xFF800000)),
                      ),
                      title: const Text('Account Management'),
                      subtitle: const Text('Manage user credentials & status'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const IctAdminAccountsScreen(),
                          ),
                        ).then((_) => _loadDashboardData());
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.security, color: Colors.blue.shade700),
                      ),
                      title: const Text('Roles & Permissions Matrix'),
                      subtitle:
                          const Text('Configure account permissions'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const IctAdminRolesScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Recent Accounts List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recently Added Users',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const IctAdminAccountsScreen(),
                              ),
                            );
                          },
                          child: const Text('View All'),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    _recentUsers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('No recent users found'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentUsers.length,
                            itemBuilder: (context, index) {
                              final user = _recentUsers[index];
                              final isActive = user['is_active'] == true;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isActive
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    child: Text(
                                      (user['full_name'] ?? 'U')[0]
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.green.shade800
                                            : Colors.red.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    user['full_name'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${user['username']} • ${user['account_type'] ?? 'User'}',
                                  ),
                                  trailing: Chip(
                                    label: Text(
                                      isActive ? 'Active' : 'Disabled',
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.green.shade900
                                            : Colors.red.shade900,
                                        fontSize: 11,
                                      ),
                                    ),
                                    backgroundColor: isActive
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}