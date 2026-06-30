// lib/screens/dashboard/signee_dashboard.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../theme/app_theme.dart';
import '../../services/session_manager.dart';
import '../../models/user_role.dart';

class SigneeDashboardScreen extends StatefulWidget {
  const SigneeDashboardScreen({super.key});

  @override
  State<SigneeDashboardScreen> createState() => _SigneeDashboardScreenState();
}

class _SigneeDashboardScreenState extends State<SigneeDashboardScreen> {
  bool _isLoading = true;
  
  // Lists and KPI counters
  List<dynamic> _actionableDocs = [];
  
  int _awaitingSignatureCount = 0;
  int _signedCount = 0;
  int _returnedCount = 0;
  int _totalOfficeCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final userId = SessionManager().userId;
    if (userId == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Reusing the comprehensive endpoint to get ALL documents at this office
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/processors/$userId/documents'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            
            // Calculate KPIs based on the status of documents currently at this office
            _awaitingSignatureCount = data.where((d) => d['status'].toString().toLowerCase() == 'in verification').length;
            _signedCount = data.where((d) => d['status'].toString().toLowerCase() == 'signed').length;
            _returnedCount = data.where((d) => d['status'].toString().toLowerCase() == 'action required').length;
            _totalOfficeCount = data.length;

            // Filter the actionable list specifically for the Signee (Only 'In Verification')
            _actionableDocs = data.where((d) => d['status'].toString().toLowerCase() == 'in verification').toList();
            
            _isLoading = false;
          });
        }
      } else {
        _showError('Failed to load dashboard data.');
      }
    } catch (e) {
      _showError('Connection error while fetching data.');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatDateString(String? isoString) {
    if (isoString == null) return 'Recent';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
             '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Recent';
    }
  }

  // ==========================================
  // API ACTION: SIGN DOCUMENT
  // ==========================================
  Future<void> _signDocument(String qrCode) async {
    final userId = SessionManager().userId;
    
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/documents/$qrCode/sign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'u_id': userId,
          'o_id': 0, // Backend auto-detects exact office ID based on u_id
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document signed successfully.'), backgroundColor: Colors.green)
          );
        }
        _fetchDashboardData(); // Refresh the KPIs and lists
      } else {
        final error = json.decode(response.body)['error'] ?? 'Failed to sign document.';
        _showError(error);
      }
    } catch (e) {
      _showError('Connection error while signing document.');
    }
  }

  // ==========================================
  // API ACTION: RETURN DOCUMENT
  // ==========================================
  Future<void> _sendBackDocument(String qrCode, String comment) async {
    final userId = SessionManager().userId;
    
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/documents/$qrCode/send-back'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'u_id': userId,
          'o_id': 0, // Backend auto-detects exact office ID based on u_id
          'comment': comment,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document returned to originator.'), backgroundColor: Colors.orange)
          );
        }
        _fetchDashboardData(); // Refresh the KPIs and lists
      } else {
        final error = json.decode(response.body)['error'] ?? 'Failed to return document.';
        _showError(error);
      }
    } catch (e) {
      _showError('Connection error while returning document.');
    }
  }

  // ==========================================
  // MODAL: SIGN CONFIRMATION
  // ==========================================
  void _showSignDialog(String qrCode, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve & Sign'),
        content: Text('Are you sure you want to sign "$title"?\n\nThis will mark the document as Signed and ready for the Processor to scan out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signDocument(qrCode);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sign Document', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODAL: RETURN WITH COMMENT
  // ==========================================
  void _showReturnDialog(String qrCode, String title) {
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to return "$title". Please provide a reason for the originator:'),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g., Missing attachment on page 2',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason before returning.'))
                );
                return;
              }
              Navigator.pop(context);
              _sendBackDocument(qrCode, commentController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Return Document', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = SessionManager().currentRole;
    if (role != UserRole.signee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCF6F6),
      appBar: AppBar(
        title: const Text('BSU Portal (Signee)'),
        actions: buildAppBarActions(context),
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
                    const Text('Hello, Signee', style: TextStyle(color: Colors.black54)),
                    const Text('Document Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // RESTORED KPI GRID
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.8,
                      children: [
                        _buildStatCard(_awaitingSignatureCount.toString(), 'AWAITING SIGNATURE', Colors.white, Colors.blue.shade200),
                        _buildStatCard(_signedCount.toString(), 'SIGNED (PENDING OUT)', Colors.white, Colors.green.shade200),
                        _buildStatCard(_returnedCount.toString(), 'RETURNED', Colors.white, Colors.orange.shade200),
                        _buildStatCard(_totalOfficeCount.toString(), 'TOTAL AT OFFICE', Colors.white, Colors.grey.shade300),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_actionableDocs.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            'All caught up!\nNo documents are currently awaiting your verification.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ),
                      )
                    else ...[
                      const Text('Action Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._actionableDocs.map((doc) => _buildDocumentCard(doc)),
                    ]
                  ],
                ),
              ),
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

  Widget _buildDocumentCard(dynamic doc) {
    final title = doc['title'] ?? 'Untitled Document';
    final requestor = doc['requestor'] ?? 'Unknown Requestor';
    final formType = doc['form_type'] ?? 'Standard Process';
    final qrCode = doc['qr_code'] ?? '';
    final timeIn = _formatDateString(doc['time_in']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_document, color: Colors.blue.shade600, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('$formType • $requestor', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('Arrived: $timeIn', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('In Verification', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('QR: $qrCode', style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'monospace')),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _showReturnDialog(qrCode, title),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryRed,
                      side: const BorderSide(color: AppTheme.primaryRed),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Return', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showSignDialog(qrCode, title),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Sign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}