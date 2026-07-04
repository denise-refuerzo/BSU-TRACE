import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../config.dart';

class DocumentDetailsScreen extends StatefulWidget {
  final int docId; 

  const DocumentDetailsScreen({super.key, required this.docId});

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  bool _isLoading = true;
  bool _isQrExpanded = false;
  Map<String, dynamic> _docData = {};

  @override
  void initState() {
    super.initState();
    _fetchDocumentDetails();
  }

  Future<void> _fetchDocumentDetails() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/documents/${widget.docId}/details'));
      if (response.statusCode == 200) {
        setState(() {
          _docData = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching doc details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String? isoDate) {
    if (isoDate == null) return 'Pending';
    try {
      final d = DateTime.parse(isoDate).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
      final min = d.minute.toString().padLeft(2, '0');
      return '${months[d.month - 1]} ${d.day}, $hour:$min $ampm';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatDateOnly(String? isoDate) {
    if (isoDate == null) return 'Not Set';
    try {
      final d = DateTime.parse(isoDate).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BSU Institutional Portal'),
        iconTheme: const IconThemeData(color: AppTheme.primaryRed),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
        : Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryRed,
              onRefresh: () async {
                await _fetchDocumentDetails();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Pull-down physics added
                padding: const EdgeInsets.only(left: 20.0, top: 20.0, right: 20.0, bottom: 100.0),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    
                    Row(children: [
                      Expanded(child: _buildInfoBox('Requestor', _docData['requestor'] ?? 'Unknown', Icons.person_outline)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoBox('Form Type', _docData['form_type'] ?? 'Unknown', Icons.account_balance)),
                    ]),
                    const SizedBox(height: 16),
            
                    _buildCompletionCard(_formatDateOnly(_docData['edc']), _docData['status'] ?? 'Unknown'),
                    const SizedBox(height: 16),
            
                    _buildCollapsibleQrSection(),
                    const SizedBox(height: 16),
            
                    _buildProcessingRoute(),
                  ],
                ),
              ),
            ),
          ),
          
          // Sticky Footer
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, color: AppTheme.primaryRed),
              label: const Text('Download QR Code', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: AppTheme.primaryRed)),
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('DOCUMENT TITLE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(_docData['title'] ?? 'Untitled Document', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('🛡 ${_docData['qr_code'] ?? 'No Tracking Code'}', style: const TextStyle(color: Colors.grey))
    ])
  );

  Widget _buildInfoBox(String title, String val, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 8),
      Text(val, style: const TextStyle(fontWeight: FontWeight.bold))
    ])
  );

  Widget _buildCompletionCard(String date, String status) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Estimated Completion', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: status == 'Completed' ? Colors.green : AppTheme.primaryRed, borderRadius: BorderRadius.circular(4)),
          child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        )
      ],
    ),
  );

  Widget _buildCollapsibleQrSection() => Column(
    children: [
      InkWell(
        onTap: () => setState(() => _isQrExpanded = !_isQrExpanded),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_isQrExpanded ? 'Hide QR Code' : 'View QR Code', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(_isQrExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white)
          ])
        ),
      ),
      if (_isQrExpanded) Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
        child: Column(children: [
          Container(height: 150, width: 150, color: Colors.grey.shade100, child: const Center(child: Text("QR Placeholder"))),
          const SizedBox(height: 16),
          const Text('Scan this code at any BSU kiosk to instantly view document status or verify authenticity.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13))
        ]),
      )
    ],
  );

  Widget _buildProcessingRoute() {
    List<dynamic> history = _docData['history'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          const Text('Processing Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          
          if (history.isEmpty)
            const Text('No routing data available.', style: TextStyle(color: Colors.grey)),
            
          ...history.asMap().entries.map((entry) {
            int idx = entry.key;
            var log = entry.value;
            
            bool isLast = idx == history.length - 1;
            bool isDone = log['current_status'] == 'Completed' || log['current_status'] == 'Signed';
            bool isCurrent = isLast && !isDone;

            String officeName = log['office_name'] ?? 'Unknown Office';
            String subtitle = isDone 
                ? 'Processed on ${_formatDateTime(log['time_in'])}' 
                : 'Current Status: ${log['current_status']}';

            return _buildRouteStep(officeName, subtitle, isDone, isCurrent: isCurrent, isLast: isLast);
          }),
        ]
      ),
    );
  }

  Widget _buildRouteStep(String title, String subtitle, bool isDone, {bool isCurrent = false, bool isLast = false}) => IntrinsicHeight(
    child: Row(children: [
      Column(
        children: [
          Container(
            width: 12, height: 12, 
            decoration: BoxDecoration(
              color: isDone ? AppTheme.primaryRed : (isCurrent ? AppTheme.primaryRed : Colors.grey.shade300), 
              shape: BoxShape.circle
            )
          ), 
          if (!isLast) 
            Expanded(child: Container(width: 2, color: Colors.red.shade200, margin: const EdgeInsets.symmetric(vertical: 4)))
        ]
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDone || isCurrent ? Colors.black : Colors.grey)), 
            Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)), 
            const SizedBox(height: 16)
          ]
        )
      )
    ]),
  );
}