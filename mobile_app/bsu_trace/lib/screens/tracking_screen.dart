// lib/screens/tracking_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';
import '../models/user_role.dart';
import '../services/session_manager.dart';
import '../config.dart';
import 'document_details_screen.dart';
import '../widgets/dialogs/tracking_document_dialog.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isLoading = true;
  List<dynamic> _recentDocuments = [];
  Map<String, dynamic>? _liveDocument;

  @override
  void initState() {
    super.initState();
    _fetchTrackingData();
  }

  Future<void> _fetchTrackingData() async {
    final userId = SessionManager().userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/users/$userId/documents'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        setState(() {
          _recentDocuments = data;
          
          // Grab the most recently updated active document for the Tracking Card
          if (data.isNotEmpty) {
            _liveDocument = data.firstWhere(
              (doc) => doc['status'] != 'Completed',
              orElse: () => data.first,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching tracking data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Tracking'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
        : SingleChildScrollView(
        // --- CHANGE THIS LINE ---
        padding: const EdgeInsets.only(left: 20.0, top: 20.0, right: 20.0, bottom: 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- LIVE DOCUMENT TRACKING ---
            _buildTrackingCard(),
            const SizedBox(height: 24),
            
            // --- RECENT SUBMISSIONS ---
            const Text('Recent Submissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildRecentSubmissionsTable(context),
          ],
        ),
      ),
      floatingActionButton: SessionManager().currentRole == UserRole.user
          ? FloatingActionButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const TrackingDocumentDialog(),
              ),
              backgroundColor: AppTheme.primaryRed,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by document title...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.filter_list, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTrackingCard() {
    if (_liveDocument == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
        child: const Text('No active documents currently being tracked.', style: TextStyle(color: Colors.grey)),
      );
    }

    String title = _liveDocument!['title'] ?? 'Unknown Document';
    String status = _liveDocument!['status'] ?? 'pending';

    // Map Database Status to UI Nodes
    bool isCompleted = status == 'Completed';
    bool step1Done = true; 
    bool step2Done = status == 'In Verification' || status == 'Signed' || status == 'Action Required' || isCompleted;
    bool step3Done = status == 'Signed' || isCompleted;
    bool step4Done = isCompleted;

    bool step2Active = status == 'pending';
    bool step3Active = status == 'In Verification' || status == 'Action Required';
    bool step4Active = status == 'Signed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Document Tracking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                decoration: BoxDecoration(color: isCompleted ? Colors.green : AppTheme.primaryRed, borderRadius: BorderRadius.circular(4)), 
                child: Text(isCompleted ? 'COMPLETED' : 'IN PROGRESS', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          _buildTimelineNode('SUBMITTED', step1Done ? 'Completed' : 'Pending', Icons.check, step1Done, step1Done),
          _buildTimelineNode('PAYMENT VERIFIED', step2Done ? 'Completed' : (step2Active ? 'In processing...' : 'Pending'), Icons.verified_outlined, step2Done, step2Done, isActive: step2Active),
          _buildTimelineNode('REGISTRAR REVIEW', step3Done ? 'Completed' : (step3Active ? 'In processing...' : 'Pending'), Icons.description_outlined, step3Done, step3Done, isActive: step3Active),
          _buildTimelineNode('FINAL APPROVAL', step4Done ? 'Completed' : (step4Active ? 'In processing...' : 'Pending'), Icons.pin_drop_outlined, step4Done, step4Done, isLast: true, isActive: step4Active),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(String title, String subtitle, IconData icon, bool isPast, bool isCompleted, {bool isActive = false, bool isLast = false}) {
    Color activeColor = AppTheme.primaryRed;
    Color inactiveColor = Colors.grey.shade300;
    Color currentColor = isCompleted || isActive ? activeColor : inactiveColor;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: isCompleted ? activeColor : (isActive ? Colors.red.shade50 : Colors.white), borderRadius: BorderRadius.circular(8), border: Border.all(color: currentColor, width: 2)), child: Icon(icon, color: isCompleted ? Colors.white : currentColor, size: 16)),
              if (!isLast) Expanded(child: Container(width: 2, color: isCompleted ? activeColor : inactiveColor, margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: currentColor, fontSize: 12)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)), const SizedBox(height: 24)])),
        ],
      ),
    );
  }

  Widget _buildRecentSubmissionsTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
            child: Row(children: const [Expanded(child: Text('DOCUMENT NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))), Expanded(child: Text('CURRENT LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))]),
          ),
          if (_recentDocuments.isEmpty)
            const Padding(padding: EdgeInsets.all(16.0), child: Text("No documents found.", style: TextStyle(color: Colors.grey))),
          
          // Pass the entire document map to the row builder
          ..._recentDocuments.map((doc) => _buildSubmissionRow(context, doc)),
        ],
      ),
    );
  }

  Widget _buildSubmissionRow(BuildContext context, Map<String, dynamic> doc) {
    String name = doc['title'] ?? 'Unknown';
    String location = doc['current_location'] ?? 'Pending Route';
    String displayName = name.length > 18 ? '${name.substring(0, 15)}...' : name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.red.shade50))),
      child: Row(
        children: [
          Expanded(child: Text(displayName, style: const TextStyle(fontSize: 13))),
          Expanded(child: Text(location, style: const TextStyle(fontSize: 13, color: Colors.black54))),
          GestureDetector(
            // Pass the specific ID to the details screen!
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => DocumentDetailsScreen(docId: doc['ini_id'])
            )),
            child: const Icon(Icons.remove_red_eye_outlined, color: AppTheme.primaryRed, size: 20),
          )
        ],
      ),
    );
  }
}