import 'package:flutter/material.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../models/user_role.dart';
import 'document_details_screen.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Tracking'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
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
      floatingActionButton: currentUserRole == UserRole.user
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
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(4)), child: const Text('IN PROGRESS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Transcript_Request_#8842.pdf', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _buildTimelineNode('SUBMITTED', 'Oct 24, 09:15 AM', Icons.check, true, true),
          _buildTimelineNode('PAYMENT VERIFIED', 'Oct 24, 10:30 AM', Icons.check, true, true),
          _buildTimelineNode('REGISTRAR REVIEW', 'In processing...', Icons.description_outlined, true, false, isActive: true),
          _buildTimelineNode('FINAL APPROVAL', 'Pending', Icons.pin_drop_outlined, false, false, isLast: true),
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
          _buildSubmissionRow(context, 'Study_Leave_For...', 'HR Department'),
          _buildSubmissionRow(context, 'Grad_Clearance_...', 'Faculty Office'),
          _buildSubmissionRow(context, 'Transcript_Offici...', 'Released'),
        ],
      ),
    );
  }

  Widget _buildSubmissionRow(BuildContext context, String name, String location) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.red.shade50))),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
          Expanded(child: Text(location, style: const TextStyle(fontSize: 13, color: Colors.black54))),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentDetailsScreen())),
            child: const Icon(Icons.remove_red_eye_outlined, color: AppTheme.primaryRed, size: 20),
          )
        ],
      ),
    );
  }
}

class TrackingDocumentDialog extends StatefulWidget {
  const TrackingDocumentDialog({super.key});
  @override
  State<TrackingDocumentDialog> createState() => _TrackingDocumentDialogState();
}

class _TrackingDocumentDialogState extends State<TrackingDocumentDialog> {
  bool _isVerified = false;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const TextField(decoration: InputDecoration(labelText: 'Document Title')),
            const SizedBox(height: 20),
            CheckboxListTile(title: const Text('Verify accuracy'), value: _isVerified, onChanged: (val) => setState(() => _isVerified = val!), activeColor: AppTheme.primaryRed),
            ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed), child: const Text('Submit', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}