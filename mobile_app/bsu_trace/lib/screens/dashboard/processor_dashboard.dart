// lib/screens/dashboard/processor_dashboard.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/modals/document_scanner_modal.dart';
import '../../services/session_manager.dart';
import '../../models/user_role.dart';

class ProcessorDashboardScreen extends StatefulWidget {
  const ProcessorDashboardScreen({super.key});

  @override
  State<ProcessorDashboardScreen> createState() => _ProcessorDashboardScreenState();
}

class _ProcessorDashboardScreenState extends State<ProcessorDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _documents = [];
  int _totalCount = 0;
  int _actionRequiredCount = 0;
  int _completedCount = 0;
  int _awaitingScanInCount = 0;
  int _pendingCount = 0;
  int _inVerificationCount = 0;
  int _totalIncomingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // EXACT BUSINESS RULE STATUS LOGIC
String _resolveStatus(dynamic doc) {
    String dbStatus = (doc['status'] ?? '').toString().toLowerCase();
    bool isAtCurrentOffice = doc['is_at_current_office'] == true || doc['is_at_current_office'] == 'true';
    bool isCompletedByMe = doc['is_completed_by_me'] == true || doc['is_completed_by_me'] == 'true';

    // 1. Completed state
    if (dbStatus == 'completed' || isCompletedByMe) {
      return 'completed';
    }

    if (isAtCurrentOffice) {
      // 2. Awaiting scan-in
      if (doc['time_in'] == null) return 'awaiting scan in'; 
      
      // 3. Map statuses clearly instead of returning 'pending'
      if (dbStatus == 'in verification') return 'in verification';
      if (dbStatus == 'signed') return 'signed';
      if (dbStatus == 'action required') return 'action required';
      
      return 'pending'; 
    } else {
      // 4. Currently at another office
      return 'incoming'; 
    }
  }

  Future<void> _fetchDashboardData() async {
    final userId = SessionManager().userId;
    if (userId == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Fetches using your original comprehensive endpoint (Endpoint 5.5 in server.js)
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/processors/$userId/documents'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          // Update this section inside _fetchDashboardData
        setState(() {
          _documents = data;
          _totalCount = data.length;

          // Use a helper to identify completed status (matches string "completed" OR ID "5")
          bool isCompleted(dynamic d) {
            final status = d['status']?.toString().toLowerCase() ?? '';
            return status == 'completed' || status == '5';
          }

          bool isPending(dynamic d) {
            final status = d['status']?.toString().toLowerCase() ?? '';
            return status == 'pending' || status == '1';
          }

          bool isActionRequired(dynamic d) {
            final status = d['status']?.toString().toLowerCase() ?? '';
            return status == 'action required' || status == '4';
          }

          _pendingCount = data.where(isPending).length;
          _actionRequiredCount = data.where(isActionRequired).length;
          _completedCount = data.where(isCompleted).length;

  _isLoading = false;
});
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load dashboard data.')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error while fetching data.')));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'awaiting scan in': return Colors.purple;
      case 'pending': return Colors.orange;
      case 'in verification': return Colors.blue;
      case 'incoming': return Colors.grey;
      case 'verified': return Colors.green;
      case 'completed': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _formatDateString(String? isoString) {
    if (isoString == null) return 'Recent';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = SessionManager().currentRole;
    if (role != UserRole.processor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Prioritize documents actually sitting AT the office
    final priorityDoc = _documents.firstWhere(
      (doc) => _resolveStatus(doc) == 'awaiting scan in' || _resolveStatus(doc) == 'pending',
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFCF6F6),
      appBar: AppBar(
        title: const Text('BSU Portal (Processor)'), 
        actions: buildAppBarActions(context)
      ),
      drawer: const AppDrawer(),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
        : RefreshIndicator(
            onRefresh: _fetchDashboardData,
            color: AppTheme.primaryRed,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hello, Processor', style: TextStyle(color: Colors.black54)),
                  const Text('Document Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // YOUR RESTORED 4 KPIs
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _buildStatCard(_awaitingScanInCount.toString(), 'AWAITING SCAN IN', Colors.white, Colors.purple.shade100),
                      _buildStatCard(_pendingCount.toString(), 'PENDING', Colors.white, Colors.orange.shade100),
                      _buildStatCard(_inVerificationCount.toString(), 'IN VERIFICATION', Colors.white, Colors.blue.shade100),
                      _buildStatCard(_totalIncomingCount.toString(), 'TOTAL INCOMING', Colors.white, Colors.grey.shade300),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  if (priorityDoc != null) ...[
                    const Text('Current Priority', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildPriorityCard(priorityDoc),
                    const SizedBox(height: 24),
                  ],

                  const Text('Recent Queue Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_documents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('No documents currently routed to your office.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._documents.take(10).map((doc) {
                      final title = doc['title'] ?? 'Untitled Document';
                      final office = doc['origin_office'] ?? 'Unknown Office';
                      final date = _formatDateString(doc['created_at']);
                      final rawStatus = _resolveStatus(doc);
                      
                      final formattedStatus = rawStatus.split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join(' ');

                      return _buildActivityItem(title, '$office • $date', formattedStatus, _getStatusColor(rawStatus));
                    }),
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // AWAIT the scanner modal so the dashboard refreshes immediately when closed!
          await showDialog(
            context: context,
            builder: (context) => const DocumentScannerModal(),
          );
          _fetchDashboardData();
        },
        backgroundColor: AppTheme.primaryRed,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Scan Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatCard(String count, String label, Color bgColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: borderColor, width: 2)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPriorityCard(dynamic doc) {
    final title = doc['title'] ?? 'Untitled Document';
    final office = doc['origin_office'] ?? 'Unknown Office';
    final formType = doc['form_type'] ?? 'Standard Process';
    
    final rawStatus = _resolveStatus(doc);
    final statusDisplay = rawStatus.toUpperCase();

    final bool isVerified = rawStatus == 'verified';
    final bool isProcessing = rawStatus == 'pending' || rawStatus == 'in verification';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)), 
                child: Text(statusDisplay, style: const TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold))
              )
            ],
          ),
          const SizedBox(height: 4),
          Text('$office • $formType', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStepNode(true, 'Submission'),
              _buildConnector(isProcessing || isVerified),
              _buildStepNode(isProcessing || isVerified, 'Processing'),
              _buildConnector(isVerified),
              _buildStepNode(isVerified, 'Verified'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStepNode(bool isActive, String label) {
    return Column(children: [
      Container(
        width: 24, height: 24, 
        decoration: BoxDecoration(color: isActive ? AppTheme.primaryRed : Colors.grey.shade200, shape: BoxShape.circle), 
        child: isActive ? const Icon(Icons.check, color: Colors.white, size: 14) : null
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 9, color: isActive ? AppTheme.primaryRed : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal))
    ]);
  }

  Widget _buildConnector(bool isActive) => Expanded(
    child: Container(height: 2, color: isActive ? AppTheme.primaryRed : Colors.grey.shade200, margin: const EdgeInsets.only(bottom: 15))
  );

  Widget _buildActivityItem(String title, String subtitle, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: statusColor.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)])),
          Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10))
        ],
      ),
    );
  }
}