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
  bool _isAscending = false;
  
  // 1. Add state for the selected status filter
  String _selectedStatus = 'All Status';

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
            String dateAStr = a['created_at'] ?? a['updated_at'] ?? '1970-01-01T00:00:00+08:00';
            String dateBStr = b['created_at'] ?? b['updated_at'] ?? '1970-01-01T00:00:00+08:00';

            dateAStr = dateAStr.replaceAll(' ', 'T');
            if (!dateAStr.endsWith('Z') && !dateAStr.contains('+')) dateAStr += '+08:00';

            dateBStr = dateBStr.replaceAll(' ', 'T');
            if (!dateBStr.endsWith('Z') && !dateBStr.contains('+')) dateBStr += '+08:00';

            DateTime dateA = DateTime.tryParse(dateAStr) ?? DateTime.utc(1970);
            DateTime dateB = DateTime.tryParse(dateBStr) ?? DateTime.utc(1970);
            
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
                    _buildFilterRow(),
                    const SizedBox(height: 24),
                    
                    // 2. Filter the documents list based on _selectedStatus state
                    ...documents.where((doc) {
                      if (_selectedStatus == 'All Status') return true;
                      
                      // Normalize strings to lowercase to ensure matching works safely
                      String docStatus = (doc['status'] ?? 'pending').toString().toLowerCase();
                      return docStatus == _selectedStatus.toLowerCase();
                    }).map((doc) => _buildDocumentCard(context, doc)),
                    
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

  Widget _buildFilterRow() => Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedStatus, // Bind to state
                  // 3. Align Dropdown items perfectly with the DB `status` table
                  items: [
                    'All Status', 
                    'Pending', 
                    'In Verification', 
                    'Signed', 
                    'Action Required', 
                    'Completed', 
                    'Verified', 
                    'Approved'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value, 
                      child: Text(value, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedStatus = newValue; // Update state and rebuild
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _isAscending ? 'Oldest' : 'Newest', 
                items: ['Newest', 'Oldest'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value, 
                    child: Text(value, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _isAscending = (newValue == 'Oldest');
                    fetchDocuments();
                  });
                },
              ),
            ),
          ),
        ],
      );

  Widget _buildDocumentCard(BuildContext context, Map<String, dynamic> document) {
    final String trackingId = document['qr_code'] ?? document['tracking_id'] ?? 'N/A';
    final String title = document['title'] ?? 'No Title';
    final String form = document['form_type'] ?? 'N/A';
    final String origin = document['origin_office'] ?? 'N/A';
    
    // Capitalize status for the UI (so db's "pending" shows as "Pending")
    final String rawStatus = document['status'] ?? 'Pending';
    final String status = rawStatus.isEmpty ? 'Pending' : rawStatus[0].toUpperCase() + rawStatus.substring(1);

    String time = 'N/A';
    String? dbTime = document['created_at'] ?? document['updated_at'];

    if (dbTime != null) {
      String normalizedTime = dbTime.replaceAll(' ', 'T');
      if (!normalizedTime.endsWith('Z') && !normalizedTime.contains('+')) {
        normalizedTime += '+08:00';
      }

      DateTime? parsedDate = DateTime.tryParse(normalizedTime);
      
      if (parsedDate != null) {
        DateTime nowPht = DateTime.now().toUtc().add(const Duration(hours: 8));
        Duration diff = nowPht.difference(parsedDate);

        if (diff.isNegative) {
          time = 'Just now'; 
        } else if (diff.inDays >= 365) {
          int years = (diff.inDays / 365).floor();
          time = '$years ${years == 1 ? 'year' : 'years'} ago';
        } else if (diff.inDays >= 30) {
          int months = (diff.inDays / 30).floor();
          time = '$months ${months == 1 ? 'month' : 'months'} ago';
        } else if (diff.inDays > 0) {
          time = '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
        } else if (diff.inHours > 0) {
          time = '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
        } else if (diff.inMinutes > 0) {
          time = '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
        } else if (diff.inSeconds > 0) {
          time = '${diff.inSeconds} ${diff.inSeconds == 1 ? 'second' : 'seconds'} ago';
        } else {
          time = 'Just now';
        }
      }
    }

    // Assign appropriate UI colors for the newly integrated DB Statuses
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'pending':
      case 'action required':
        statusColor = Colors.orange.shade100;
        break;
      case 'in verification':
      case 'verified':
        statusColor = Colors.blue.shade100;
        break;
      case 'signed':
      case 'approved':
      case 'completed':
        statusColor = Colors.green.shade100;
        break;
      default:
        statusColor = Colors.grey.shade100;
    }

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)), 
                child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
              ),
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