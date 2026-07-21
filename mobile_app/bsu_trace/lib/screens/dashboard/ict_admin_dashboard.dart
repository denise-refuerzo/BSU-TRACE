import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../config.dart';
import '../../services/session_manager.dart';
import '../../widgets/app_bar_helper.dart';
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
  
  int _registeredPersonnel = 0;
  int _activeDocumentTracks = 0;
  int _workflowBlueprints = 0;
  int _auditStreamFeed = 0;
  
  List<dynamic> _auditLogs = [];
  List<dynamic> _stalledAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final session = SessionManager();
      final token = session.sessionToken;
      final userId = session.userId;

      if (token == null || userId == null) {
        setState(() => _isLoading = false);
        return;
      }

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
          _registeredPersonnel = data['registeredPersonnel'] ?? 0;
          _activeDocumentTracks = data['activeDocumentTracks'] ?? 0;
          _workflowBlueprints = data['workflowBlueprints'] ?? 0;
          _auditStreamFeed = data['auditStreamFeed'] ?? 0;
          _auditLogs = data['auditLogs'] ?? [];
          _stalledAlerts = data['stalledAlerts'] ?? [];
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

  String formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.parse(timestamp).toLocal();
    return DateFormat('hh:mm a').format(dt);
  }

  String formatDateTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.parse(timestamp).toLocal();
    return DateFormat('M/dd/yyyy | hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('ICT Admin Dashboard'),
        actions: buildAppBarActions(context),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
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

                    // Quick Actions
                    const Text('Management Console', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.manage_accounts, color: Color(0xFF800000)),
                            ),
                            title: const Text('Account Management', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Manage user credentials & status'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const IctAdminAccountsScreen())).then((_) => _loadDashboardData());
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.security, color: Colors.blue.shade700),
                            ),
                            title: const Text('Roles & Permissions Matrix', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Configure account permissions'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const IctAdminRolesScreen()));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Metrics Grid
                    const Text('System Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      childAspectRatio: 1.4,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(title: 'Registered Personnel', value: '$_registeredPersonnel', icon: Icons.badge, color: Colors.blue.shade700),
                        _buildStatCard(title: 'Active Document Tracks', value: '$_activeDocumentTracks', icon: Icons.route, color: Colors.green.shade700),
                        _buildStatCard(title: 'Workflow Blueprints', value: '$_workflowBlueprints', icon: Icons.account_tree, color: Colors.orange.shade700),
                        _buildStatCard(title: 'Audit Stream Feed', value: '$_auditStreamFeed', icon: Icons.stream, color: Colors.purple.shade700),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // LIVE SYSTEM-WIDE AUDIT STREAM FEED
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LIVE SYSTEM-WIDE AUDIT STREAM FEED', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF800000))),
                            const SizedBox(height: 4),
                            Text('Real-time rolling ledger tracing pipeline checkpoints and structural user actions campus-wide.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 16),
                            _auditLogs.isEmpty
                                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No audit logs available')))
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _auditLogs.length,
                                    separatorBuilder: (context, index) => Divider(height: 24, color: Colors.grey.shade200),
                                    itemBuilder: (context, index) {
                                      final log = _auditLogs[index];
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontFamily: 'sans-serif'),
                                                    children: [
                                                      TextSpan(text: '${log['full_name']} applied ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                      TextSpan(text: '"${log['action_type']}"', style: const TextStyle(color: Color(0xFF800000), fontWeight: FontWeight.bold)),
                                                    ]
                                                  )
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(formatTime(log['action_timestamp']), style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                                            ]
                                          ),
                                          const SizedBox(height: 4),
                                          Text("Document: '${log['title']}'", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.domain, size: 14, color: Colors.blueGrey),
                                              const SizedBox(width: 4),
                                              Expanded(child: Text('Location Block: ${log['office_name']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
                                            ]
                                          )
                                        ]
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // STALLED QUEUE CONGESTION ALERTS
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Text('🎉 ', style: TextStyle(fontSize: 16)),
                                Expanded(child: Text('STALLED QUEUE CONGESTION ALERTS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF800000)))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Identifies critical workflows sitting inside an office destination past 48 hours without release scans.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 16),
                            _stalledAlerts.isEmpty
                                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No stalled documents found.')))
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _stalledAlerts.length,
                                    itemBuilder: (context, index) {
                                      final alert = _stalledAlerts[index];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        color: const Color(0xFFFFF5F5),
                                        shape: RoundedRectangleBorder(
                                          side: const BorderSide(color: Color(0xFFFFD6D6)),
                                          borderRadius: BorderRadius.circular(12)
                                        ),
                                        elevation: 0,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(child: Text('${alert['title']}', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold))),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(color: const Color(0xFFD66A6A), borderRadius: BorderRadius.circular(6)),
                                                    child: Text('+${alert['hours_stuck']} HOURS', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                  )
                                                ]
                                              ),
                                              const SizedBox(height: 8),
                                              RichText(
                                                text: TextSpan(
                                                  style: const TextStyle(fontSize: 13, color: Color(0xFFD66A6A)),
                                                  children: [
                                                    const TextSpan(text: 'Stuck at: '),
                                                    TextSpan(text: '${alert['office_name']}', style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
                                                  ]
                                                )
                                              ),
                                              const SizedBox(height: 4),
                                              Text('Arrived: ${formatDateTime(alert['time_in'])}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                            ]
                                          )
                                        )
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
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
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}