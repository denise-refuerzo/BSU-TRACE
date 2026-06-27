// lib/screens/documents_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/document_scanner_modal.dart';
import '../widgets/modals/processor_document_details_modal.dart';
import '../config.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<dynamic> documents = [];
  bool isLoading = true;
  String errorMessage = '';
  Timer? _timer;
  bool _isAscending = false; // Add state for sort direction

  @override
  void initState() {
    super.initState();
    fetchDocuments();

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) fetchDocuments();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchDocuments() async {
    final String url = '${AppConfig.baseUrl}/documents';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          List<dynamic> fetchedDocs = json.decode(response.body);

          fetchedDocs.sort((a, b) {
            DateTime dateA = DateTime.tryParse(a['created_at'] ?? a['updated_at'] ?? '1970-01-01T00:00:00Z')?.toUtc() ?? DateTime(1970).toUtc();
            DateTime dateB = DateTime.tryParse(b['created_at'] ?? b['updated_at'] ?? '1970-01-01T00:00:00Z')?.toUtc() ?? DateTime(1970).toUtc();
            
            // Sort based on _isAscending state
            return _isAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
          });

          setState(() {
            documents = fetchedDocs;
            isLoading = false;
            errorMessage = '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching documents: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Documents'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : RefreshIndicator(
              onRefresh: fetchDocuments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildFilterRow(), // Updated to Row
                    const SizedBox(height: 24),
                    ...documents.map((doc) => _buildDocumentCard(context, doc)),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (context) => const DocumentScannerModal()),
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() => TextField(
        decoration: InputDecoration(
          hintText: 'Search Documents...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      );

  // New Row to hold both Filter and Sort
Widget _buildFilterRow() => Row(
        children: [
          // 1. Status Filter Dropdown
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: 'All Status',
                  items: ['All Status', 'Incoming', 'In Verification', 'Pending'].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // 2. Sort Dropdown (Replaces the IconButton)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                // Map the boolean state to a readable string
                value: _isAscending ? 'Oldest' : 'Newest', 
                items: ['Newest', 'Oldest'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value, 
                    child: Text(value, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    // Update state: 'Oldest' sets _isAscending to true, 'Newest' to false
                    _isAscending = (newValue == 'Oldest');
                    fetchDocuments(); // Re-sort and refresh the list
                  });
                },
              ),
            ),
          ),
        ],
      );

  Widget _buildDocumentCard(BuildContext context, Map<String, dynamic> document) {
    // ... (rest of _buildDocumentCard remains exactly the same as previously provided)
    final String trackingId = document['qr_code'] ?? document['tracking_id'] ?? 'N/A';
    final String title = document['title'] ?? 'No Title';
    final String form = document['form_type'] ?? 'N/A';
    final String origin = document['origin_office'] ?? 'N/A';
    final String status = document['status'] ?? 'Pending';

String time = 'N/A';
    String? dbTime = document['created_at'] ?? document['updated_at'];

    if (dbTime != null) {
      DateTime? parsedDate = DateTime.tryParse(dbTime)?.toUtc();
      if (parsedDate != null) {
        DateTime now = DateTime.now().toUtc();
        Duration diff = now.difference(parsedDate);

        // Standard logic: Use the total duration properties
        if (diff.inDays > 0) {
          time = '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
        } else if (diff.inHours > 0) {
          time = '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
        } else if (diff.inMinutes > 0) {
          time = '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
        } else {
          time = 'Just now';
        }
      }
    }

    Color statusColor = status == 'Incoming' ? Colors.red.shade100 : (status == 'Pending' ? Colors.orange.shade100 : Colors.blue.shade100);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade50)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(trackingId, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)), child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Form: $form', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text('Origin: $origin', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ProcessorDocumentDetailsModal(
                      document: document,
                      onAdHocVerification: () => Navigator.pop(context),
                      onDownloadDigitalCopy: () {},
                    )),
                child: const Text('View Details >', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}