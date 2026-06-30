// lib/screens/dashboard/signee_dashboard.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/signee_document_details_modal.dart';
import '../../services/session_manager.dart';
import '../../models/user_role.dart';
import '../../config.dart';

class SigneeDashboardScreen extends StatefulWidget {
  const SigneeDashboardScreen({super.key});

  @override
  State<SigneeDashboardScreen> createState() => _SigneeDashboardScreenState();
}

class _SigneeDashboardScreenState extends State<SigneeDashboardScreen> {
  bool isLoading = true;
  Timer? _timer;
  String? _errorMessage;

  // Live Statistics
  int pendingCount = 0;
  int signedCount = 0;
  int verificationCount = 0;
  int sentBackCount = 0;
  
  // Live Documents List
  List<dynamic> pendingDocuments = [];

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
    
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) fetchDashboardData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchDashboardData() async {
    try {
      final userId = SessionManager().userId;
      if (userId == null) {
        if (mounted) setState(() => _errorMessage = "No logged in user found.");
        return;
      }

      // 1. Fetch live pending queue for this specific signee
      final pendingFuture = http.get(
        Uri.parse('${AppConfig.baseUrl}/signees/$userId/pending-documents')
      ).timeout(const Duration(seconds: 10));
      
      // 2. Fetch all historical actions for this specific office to get total signed/sent back stats
      final timelineFuture = http.get(
        Uri.parse('${AppConfig.baseUrl}/users/$userId/processing-timeline')
      ).timeout(const Duration(seconds: 10));

      final results = await Future.wait([pendingFuture, timelineFuture]);
      final pendingResponse = results[0];
      final timelineResponse = results[1];

      if (pendingResponse.statusCode == 200 && timelineResponse.statusCode == 200) {
        final List<dynamic> pDocs = json.decode(pendingResponse.body);
        final List<dynamic> tDocs = json.decode(timelineResponse.body);

        int sCount = 0;
        int vCount = 0;
        int sbCount = 0;

        // Calculate historical stats from timeline
        for (var doc in tDocs) {
          String status = (doc['status'] ?? '').toString().toLowerCase();
          if (['signed', 'verified', 'approved', 'completed'].contains(status)) {
            sCount++;
          } else if (['action required', 'sent back', 'rejected'].contains(status)) {
            sbCount++;
          } else if (status == 'in verification') {
            vCount++;
          }
        }

        // Sort pending documents by newest scanned-in first
        pDocs.sort((a, b) {
          String dateAStr = a['time_in'] ?? a['created_at'] ?? '1970-01-01T00:00:00+08:00';
          String dateBStr = b['time_in'] ?? b['created_at'] ?? '1970-01-01T00:00:00+08:00';

          dateAStr = dateAStr.replaceAll(' ', 'T');
          if (!dateAStr.endsWith('Z') && !dateAStr.contains('+')) dateAStr += '+08:00';
          dateBStr = dateBStr.replaceAll(' ', 'T');
          if (!dateBStr.endsWith('Z') && !dateBStr.contains('+')) dateBStr += '+08:00';

          DateTime dateA = DateTime.tryParse(dateAStr) ?? DateTime.utc(1970);
          DateTime dateB = DateTime.tryParse(dateBStr) ?? DateTime.utc(1970);
          
          return dateB.compareTo(dateA); 
        });

        if (mounted) {
          setState(() {
            pendingCount = pDocs.length;
            signedCount = sCount;
            verificationCount = vCount;
            sentBackCount = sbCount;
            pendingDocuments = pDocs.take(5).toList(); // Take latest 5 for the dashboard
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Server Error. Pending Code: ${pendingResponse.statusCode}, Timeline Code: ${timelineResponse.statusCode}';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching signee dashboard data: $e');
      if (mounted) setState(() => _errorMessage = 'Network Error: Unable to reach the server.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Signee Dashboard'),
        actions: buildAppBarActions(context), 
      ),
      drawer: const AppDrawer(),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13))),
                          ],
                        ),
                      ),
                  
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('PENDING', pendingCount.toString().padLeft(2, '0'), Icons.pending_actions, Colors.red.shade50, AppTheme.primaryRed, valueColor: AppTheme.primaryRed),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('SIGNED', signedCount.toString().padLeft(2, '0'), Icons.draw_outlined, Colors.blue.shade50, Colors.blue.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('VERIFICATION', verificationCount.toString().padLeft(2, '0'), Icons.shield_outlined, Colors.grey.shade200, Colors.grey.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('SENT BACK', sentBackCount.toString().padLeft(2, '0'), Icons.assignment_return_outlined, Colors.red.shade50, AppTheme.primaryRed, valueColor: AppTheme.primaryRed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    _buildEfficiencyChart(),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Documents Pending',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: Colors.black87),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/signee_pending'),
                          child: Row(
                            children: const [
                              Text('View All', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, color: AppTheme.primaryRed, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (pendingDocuments.isEmpty && _errorMessage == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text("No incoming documents in the pipeline.", style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...pendingDocuments.map((doc) => _buildDocCard(
                        context: context,
                        document: doc, 
                        icon: Icons.description_outlined,
                      )),
                      
                    const SizedBox(height: 24),
                    const Text(
                      'System Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    _buildSystemStatus(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconBg, Color iconColor, {Color valueColor = Colors.black87}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: valueColor, height: 1)),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(4)), child: Icon(icon, color: iconColor, size: 20)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('Efficiency Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia')),
              SizedBox(width: 12),
              Text('2.4', style: TextStyle(color: AppTheme.primaryRed, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 4),
              Text('Avg Hours', style: TextStyle(color: Colors.black54, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildChartBar('M', 40, false), _buildChartBar('T', 60, false), _buildChartBar('W', 100, true),
                _buildChartBar('T', 50, false), _buildChartBar('F', 0, false), _buildChartBar('S', 20, false), _buildChartBar('S', 15, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(String day, double heightPct, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (heightPct > 0)
          Container(width: 32, height: (heightPct / 100) * 70, decoration: BoxDecoration(color: isActive ? AppTheme.primaryRed : Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? AppTheme.primaryRed : Colors.grey)),
      ],
    );
  }

  Widget _buildDocCard({required BuildContext context, required Map<String, dynamic> document, required IconData icon}) {
    final String title = document['title'] ?? 'No Title';
    final String id = document['qr_code'] ?? 'N/A';
    final String formType = document['form_type'] ?? 'Document';
    
    // Fallbacks to avoid null errors on historical documents
    final String office = document['origin_office'] ?? document['requestor'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppTheme.primaryRed)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('ID: $id', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final bool? signed = await showDialog<bool>(
                    context: context,
                    builder: (context) => SigneeDocumentDetailsModal(document: document),
                  );
                  // Refresh the dashboard stats automatically if a document is signed
                  if (signed == true) fetchDashboardData(); 
                },
                child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.remove_red_eye_outlined, color: AppTheme.primaryRed)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('FORM TYPE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(formType, style: const TextStyle(fontSize: 12, color: Colors.black87))],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('FROM', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(office, style: const TextStyle(fontSize: 12, color: Colors.black87))],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      decoration: BoxDecoration(color: Colors.red.shade50.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        children: [
          _buildStatusRow(Icons.lock_outline, 'Digital Seal', 'Active', isGreen: true), Divider(height: 1, color: Colors.red.shade100),
          _buildStatusRow(Icons.cloud_queue, 'Cloud Storage', 'Connected', isGreen: true), Divider(height: 1, color: Colors.red.shade100),
          _buildStatusRow(Icons.sync_alt, 'Audit Sync', 'Last: 2m ago', isGreen: false),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String title, String status, {required bool isGreen}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 20), const SizedBox(width: 16), Expanded(child: Text(title, style: const TextStyle(color: Colors.black87, fontSize: 14))),
          if (isGreen) Container(margin: const EdgeInsets.only(right: 6), width: 8, height: 8, decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle)),
          Text(status, style: TextStyle(color: isGreen ? Colors.teal : Colors.black54, fontSize: 12, fontWeight: isGreen ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}