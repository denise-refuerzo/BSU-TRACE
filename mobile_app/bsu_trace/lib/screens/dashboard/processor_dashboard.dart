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
  int _incomingCount = 0;
  int _inVerificationCount = 0;
  int _verifiedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // Helper to determine status based on processed_document fields
  String _resolveStatus(dynamic doc) {
    if (doc['time_out'] != null) return 'Verified';
    if (doc['time_in'] != null) return 'In Verification';
    return 'Pending';
  }

  Future<void> _fetchDashboardData() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/documents'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _documents = data;
            // Updated stats based on processed_document timestamps
            _incomingCount = data.where((d) => d['time_in'] == null).length;
            _inVerificationCount = data.where((d) => d['time_in'] != null && d['time_out'] == null).length;
            _verifiedCount = data.where((d) => d['time_out'] != null).length;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load dashboard data.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection error while fetching data.')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in verification':
        return AppTheme.primaryRed;
      default:
        return Colors.grey;
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
    // GATEKEEPER
    final role = SessionManager().currentRole;
    if (role != UserRole.processor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Find the first document that needs attention for the Priority Card
    final priorityDoc = _documents.firstWhere(
      (doc) => _resolveStatus(doc) != 'Verified',
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
                  
                  // Dynamic Stats Row
                  Row(
                    children: [
                      _buildStatCard(_incomingCount.toString(), 'INCOMING', Colors.white, Colors.red.shade100),
                      const SizedBox(width: 12),
                      _buildStatCard(_inVerificationCount.toString(), 'IN VERIFICATION', Colors.white, Colors.orange.shade100),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(_verifiedCount.toString(), 'VERIFIED', Colors.white, Colors.green.shade100, isFullWidth: true),
                  const SizedBox(height: 24),
                  
                  // Priority Card logic
                  if (priorityDoc != null) ...[
                    const Text('Current Priority', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildPriorityCard(priorityDoc),
                    const SizedBox(height: 24),
                  ],

                  // Dynamic Activity List
                  const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_documents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('No recent activity found.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._documents.take(5).map((doc) {
                      final title = doc['title'] ?? 'Untitled Document';
                      final office = doc['origin_office'] ?? 'Unknown Office';
                      final date = _formatDateString(doc['created_at']);
                      final status = _resolveStatus(doc);

                      return _buildActivityItem(
                        title, 
                        '$office • $date', 
                        status, 
                        _getStatusColor(status)
                      );
                    }),
                ],
              ),
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
        width: isFullWidth ? double.infinity : null,
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

  Widget _buildPriorityCard(dynamic doc) {
    final title = doc['title'] ?? 'Untitled Document';
    final office = doc['origin_office'] ?? 'Unknown Office';
    final formType = doc['form_type'] ?? 'Standard Process';
    final status = _resolveStatus(doc).toUpperCase();

    // Logic for steps
    final bool isVerified = status == 'VERIFIED';
    final bool isInVerification = status == 'IN VERIFICATION';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title, 
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)), 
                child: Text(
                  status, 
                  style: const TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold)
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text('$office • $formType', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStepNode(true, 'Submission'),
              _buildConnector(isInVerification || isVerified),
              _buildStepNode(isInVerification || isVerified, 'In Verification'),
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
        width: 24, 
        height: 24, 
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryRed : Colors.grey.shade200, 
          shape: BoxShape.circle
        ), 
        child: isActive ? const Icon(Icons.check, color: Colors.white, size: 14) : null
      ),
      const SizedBox(height: 4),
      Text(
        label, 
        style: TextStyle(
          fontSize: 9, 
          color: isActive ? AppTheme.primaryRed : Colors.grey, 
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal
        )
      )
    ]);
  }

  Widget _buildConnector(bool isActive) => Expanded(
    child: Container(
      height: 2, 
      color: isActive ? AppTheme.primaryRed : Colors.grey.shade200, 
      margin: const EdgeInsets.only(bottom: 15)
    )
  );

  Widget _buildActivityItem(String title, String subtitle, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade50)),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: AppTheme.primaryRed.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), 
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)
              ]
            )
          ),
          Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10))
        ],
      ),
    );
  }
}