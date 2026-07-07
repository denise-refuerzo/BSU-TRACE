import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar_helper.dart';
import '../../../widgets/app_drawer.dart';
import '../../services/session_manager.dart';
import '../../models/user_role.dart';

class IctAdminDashboardScreen extends StatefulWidget {
  const IctAdminDashboardScreen({super.key});

  @override
  State<IctAdminDashboardScreen> createState() => _IctAdminDashboardScreenState();
}

class _IctAdminDashboardScreenState extends State<IctAdminDashboardScreen> {
  bool _isLoading = true;
  
  // Real data state variables
  int _activeDocumentTracks = 0;
  int _registeredPersonnel = 0;
  int _workflowBlueprints = 0;
  List<dynamic> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  void _showAlertDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final statsResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/dashboard/ict/stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final logsResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/dashboard/ict/logs'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (statsResponse.statusCode == 200 && logsResponse.statusCode == 200) {
        final statsData = json.decode(statsResponse.body);
        final logsData = json.decode(logsResponse.body);

        setState(() {
          _activeDocumentTracks = statsData['active_documents'] ?? 0;
          _registeredPersonnel = statsData['total_users'] ?? 0;
          _workflowBlueprints = statsData['total_workflows'] ?? 0;
          
          _auditLogs = (logsData['logs'] as List<dynamic>? ?? []).take(5).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showAlertDialog('Server Error', 'Failed to fetch dashboard data. Please try again.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showAlertDialog('Connection Error', 'Unable to connect to the server. Please check your network.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // GATEKEEPER
    final role = SessionManager().currentRole;
    if (role != UserRole.ictAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Aligned variables to match the Accounts and Roles screens
    const Color bgColor = Color(0xFFFDF7F6); 
    const Color cardOutlineColor = Color(0xFFE5D5D5);

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        toolbarHeight: 80,
        title: const Text(
          'Operations Control',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: buildAppBarActions(context),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardOutlineColor, height: 1.0),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: AppTheme.primaryRed,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Standardized Top Page Header Layout
                    const Text(
                      'System Telemetry & Audits', 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2)
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Real-time telemetry monitoring background data pipelines, traffic flows, and operational backlogs across campus infrastructure.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildStatCard(
                      title: 'ACTIVE DOCUMENT TRACKS',
                      value: _activeDocumentTracks.toString(),
                      icon: Icons.description_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      title: 'REGISTERED PERSONNEL',
                      value: _registeredPersonnel.toString(),
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      title: 'WORKFLOW BLUEPRINTS',
                      value: _workflowBlueprints.toString(),
                      icon: Icons.architecture, 
                    ),
                    const SizedBox(height: 24),

                    _buildAuditFeedSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade900.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 42, fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: AppTheme.primaryRed, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditFeedSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(margin: const EdgeInsets.only(top: 6, right: 12), width: 6, height: 16, decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(4))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LIVE SYSTEM-WIDE AUDIT\nSTREAM FEED', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.3)),
                      const SizedBox(height: 8),
                      Text('Real-time rolling ledger tracing pipeline checkpoints and structural user actions campus-wide.', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.red.shade100, height: 1, thickness: 1.5),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: _auditLogs.isEmpty
                ? const Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text('No recent audit logs available.', style: TextStyle(color: Colors.black54))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _auditLogs.length,
                    itemBuilder: (context, index) {
                      final log = _auditLogs[index];
                      final bool isLast = index == _auditLogs.length - 1;
                      
                      final String message = log['message'] ?? 'Unknown action';
                      final String rawTime = log['timestamp']?.toString() ?? 'Unknown time';

                      return _buildTimelineItem(message, rawTime, isLast);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String message, String time, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle), child: const Icon(Icons.history, color: Colors.white, size: 14)),
              if (!isLast) Expanded(child: Container(width: 2, color: Colors.red.shade100, margin: const EdgeInsets.only(top: 4, bottom: 4))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.4),
                  children: _formatLogMessage(message),
                ),
              ),
            ),
          ),
          Text(time, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.3)),
        ],
      ),
    );
  }

  List<TextSpan> _formatLogMessage(String message) {
    final parts = message.split('"');
    if (parts.length < 3) return [TextSpan(text: message)];

    List<TextSpan> spans = [];
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 != 0) {
        spans.add(TextSpan(text: '"${parts[i]}"', style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)));
      } else {
        spans.add(TextSpan(text: parts[i]));
      }
    }
    return spans;
  }
}