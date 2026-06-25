import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/new_document_modal.dart';
import '../../services/session_manager.dart';
import '../../models/user_role.dart';
import '../../config.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  bool _isLoading = true;
  String _userName = 'Loading...';
  String _userRoleDept = 'Loading...';
  
  // Dashboard Stats
  int _totalDocs = 0;
  int _pendingDocs = 0;
  int _archivedDocs = 0;
  int _completedDocs = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final userId = SessionManager().userId;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch User Profile
      final profileResponse = await http.get(Uri.parse('${AppConfig.baseUrl}/users/$userId'));
      
      // 2. Fetch User Stats (Requires the new backend endpoint provided below)
      final statsResponse = await http.get(Uri.parse('${AppConfig.baseUrl}/users/$userId/dashboard-stats'));

      if (profileResponse.statusCode == 200) {
        final profileData = json.decode(profileResponse.body);
        setState(() {
          _userName = profileData['full_name'] ?? 'Unknown User';
          _userRoleDept = '${profileData['account_type']} • ${profileData['department_name']}';
        });
      }

      if (statsResponse.statusCode == 200) {
        final statsData = json.decode(statsResponse.body);
        setState(() {
          _totalDocs = int.tryParse(statsData['total_docs'].toString()) ?? 0;
          _pendingDocs = int.tryParse(statsData['pending_docs'].toString()) ?? 0;
          _archivedDocs = int.tryParse(statsData['archived_docs'].toString()) ?? 0;
          _completedDocs = int.tryParse(statsData['completed_docs'].toString()) ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // GATEKEEPER
    final role = SessionManager().currentRole;
    if (role != UserRole.user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BSU Portal (User)'), 
        actions: buildAppBarActions(context)
      ),
      drawer: const AppDrawer(),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFB01A22)))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PROFILE SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Institutional Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.black54), 
                      const SizedBox(width: 4), 
                      Text(_userName, style: const TextStyle(color: Colors.black54))
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.work_outline, size: 16, color: Colors.black54), 
                      const SizedBox(width: 4), 
                      Text(_userRoleDept, style: const TextStyle(color: Colors.black54, fontSize: 12))
                    ]),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12), 
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), 
                  child: const Icon(Icons.account_balance, color: Color(0xFFB01A22), size: 32)
                )
              ],
            ),
            const SizedBox(height: 24),
            
            // STATISTICS GRID
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildStatCard('TOTAL DOCS', _totalDocs.toString(), Icons.folder_open, const Color(0xFFB01A22)),
                _buildStatCard('PENDING', _pendingDocs.toString(), Icons.pending_actions, const Color(0xFFB01A22)),
                _buildStatCard('ARCHIVED', _archivedDocs.toString(), Icons.archive_outlined, Colors.blueGrey),
                _buildStatCard('COMPLETED', _completedDocs.toString(), Icons.check_circle_outline, Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            
            // ACTIVE SUBMISSION FLOW
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
                    child: Text(
                      _pendingDocs > 0 
                        ? 'Current: You have $_pendingDocs document(s) pending review.' 
                        : 'No pending active submissions at the moment.', 
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54, fontSize: 13)
                    ),
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
        _buildStepNode('Review', isActive: true, isCurrent: _pendingDocs > 0),
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