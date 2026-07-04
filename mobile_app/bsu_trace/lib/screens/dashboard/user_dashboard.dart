import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

import '../ai_chat_screen.dart'; // Import the AI Chat Screen
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/new_document_modal.dart';
import '../../services/session_manager.dart';
import '../../models/user_role.dart';
import '../../config.dart';
import '../document_details_screen.dart'; 

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  bool _isLoading = true;
  String _userName = 'Loading...';
  String _userRoleDept = 'Loading...';
  
  int _totalDocs = 0;
  int _pendingDocs = 0;
  int _sentBackDocs = 0; 
  int _completedDocs = 0;

  Map<String, dynamic>? _latestDocument; 

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData(); 
    
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchDashboardData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<String> sendMessageToGemini(String message) async {
  try {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userMessage': message}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply']; 
    } else {
      return 'Sorry, I am having trouble connecting to the server right now.';
    }
  } catch (e) {
    return 'Network error. Please check your internet connection.';
  }
}

  Future<void> _fetchDashboardData({bool isBackground = false}) async {
    final userId = SessionManager().userId;

    if (userId == null) {
      if (!isBackground && mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final profileResponse = await http.get(Uri.parse('${AppConfig.baseUrl}/users/$userId'));
      final statsResponse = await http.get(Uri.parse('${AppConfig.baseUrl}/users/$userId/dashboard-stats'));
      final docsResponse = await http.get(Uri.parse('${AppConfig.baseUrl}/users/$userId/documents'));

      if (profileResponse.statusCode == 200 && mounted) {
        final profileData = json.decode(profileResponse.body);
        setState(() {
          _userName = profileData['full_name'] ?? 'Unknown User';
          _userRoleDept = '${profileData['account_type']} • ${profileData['department_name']}';
        });
      }

      if (statsResponse.statusCode == 200 && mounted) {
        final statsData = json.decode(statsResponse.body);
        setState(() {
          // Extremely safe parsing to prevent null errors
          _totalDocs = int.tryParse(statsData['total_docs']?.toString() ?? '') ?? 0;
          _pendingDocs = int.tryParse(statsData['pending_docs']?.toString() ?? '') ?? 0;
          _sentBackDocs = int.tryParse(statsData['sent_back_docs']?.toString() ?? '') ?? 0;
          _completedDocs = int.tryParse(statsData['completed_docs']?.toString() ?? '') ?? 0;
        });
      }

      if (docsResponse.statusCode == 200 && mounted) {
        final List<dynamic> docs = json.decode(docsResponse.body);
        setState(() {
          if (docs.isNotEmpty) {
            _latestDocument = docs.first; 
          }
        });
      }

    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    } finally {
      if (!isBackground && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        : RefreshIndicator(
            color: const Color(0xFFB01A22),
            onRefresh: () async {
              await _fetchDashboardData(isBackground: true);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      _buildStatCard('ACTION REQ', _sentBackDocs.toString(), Icons.assignment_return, Colors.orange),
                      _buildStatCard('COMPLETED', _completedDocs.toString(), Icons.check_circle_outline, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Active Submission Flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        
                        if (_latestDocument != null) ...[
                          _buildHorizontalStepper(_latestDocument!['status'] ?? 'pending'),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFFFF9F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade50)),
                            child: Row(
                              children: [
                                const Icon(Icons.description_outlined, color: Color(0xFFB01A22), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_latestDocument!['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text('${_latestDocument!['current_location'] ?? 'Routing'} • ${_latestDocument!['status'] ?? 'pending'}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => DocumentDetailsScreen(docId: _latestDocument!['ini_id'])
                                  )),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB01A22),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                  ),
                                  child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                          ),
                        ] else ...[
                          const Center(
                            child: Text(
                              'No active submissions at the moment.', 
                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54, fontSize: 13)
                            )
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 1. The New AI Chat Button
            FloatingActionButton.extended(
              heroTag: 'ai_chat_btn', // Required when using multiple FABs
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AiChatScreen()),
                );
              },
              backgroundColor: Colors.blue.shade800,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text('Ask AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(width: 16), // Spacing between the buttons
            
            // 2. Your Existing Add Document Button
            FloatingActionButton.extended(
                      onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const NewDocumentModal(),
                  );
                },
              backgroundColor: Colors.red.shade700, // Or whatever color you prefer!
              icon: const Icon(Icons.post_add, color: Colors.white),
              label: const Text('Add Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
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

  Widget _buildHorizontalStepper(String status) {
    bool isCompleted = status == 'Completed';
    bool step2Done = status == 'In Verification' || status == 'Signed' || status == 'Action Required' || isCompleted;
    bool step3Done = status == 'Signed' || isCompleted;
    bool step4Done = isCompleted;

    bool step2Active = status == 'pending';
    bool step3Active = status == 'In Verification' || status == 'Action Required';
    bool step4Active = status == 'Signed';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepNode('Submitted', isActive: true, isCompleted: true),
        Expanded(child: Container(height: 4, color: step2Done || step2Active ? const Color(0xFFB01A22) : Colors.grey.shade300)),
        _buildStepNode('Processing', isActive: step2Active || step2Done, isCompleted: step2Done, isCurrent: step2Active),
        Expanded(child: Container(height: 4, color: step3Done || step3Active ? const Color(0xFFB01A22) : Colors.grey.shade300)),
        _buildStepNode('Approval', isActive: step3Active || step3Done, isCompleted: step3Done, isCurrent: step3Active),
        Expanded(child: Container(height: 4, color: step4Done || step4Active ? const Color(0xFFB01A22) : Colors.grey.shade300)),
        _buildStepNode('Completed', isActive: step4Active || step4Done, isCompleted: step4Done, isCurrent: step4Active),
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
        Text(
          label, 
          style: TextStyle(
            fontSize: 10, 
            color: isActive || isCompleted ? const Color(0xFFB01A22) : Colors.grey, 
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal
          )
        ),
      ],
    );
  }
}