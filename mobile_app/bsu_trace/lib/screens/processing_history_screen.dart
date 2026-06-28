// lib/screens/processing_history_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/document_scanner_modal.dart';
import '../config.dart';
import '../services/session_manager.dart';

class ProcessingHistoryScreen extends StatefulWidget {
  const ProcessingHistoryScreen({super.key});

  @override
  State<ProcessingHistoryScreen> createState() => _ProcessingHistoryScreenState();
}

class _ProcessingHistoryScreenState extends State<ProcessingHistoryScreen> {
  List<dynamic> documents = [];
  List<dynamic> filteredDocuments = [];
  bool isLoading = true;
  Timer? _timer;
  
  String _searchQuery = '';
  String _selectedStatus = 'All Statuses';

  @override
  void initState() {
    super.initState();
    fetchDocuments();
    // 10-second background auto-refresh
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
    final userId = SessionManager().userId;
    if (userId == null) return;

    final String url = '${AppConfig.baseUrl}/users/$userId/documents';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          List<dynamic> fetchedDocs = json.decode(response.body);

          // Sort by newest based on updated_at
          fetchedDocs.sort((a, b) {
            String dateAStr = a['updated_at'] ?? '1970-01-01T00:00:00+08:00';
            String dateBStr = b['updated_at'] ?? '1970-01-01T00:00:00+08:00';

            dateAStr = dateAStr.replaceAll(' ', 'T');
            if (!dateAStr.endsWith('Z') && !dateAStr.contains('+')) dateAStr += '+08:00';

            dateBStr = dateBStr.replaceAll(' ', 'T');
            if (!dateBStr.endsWith('Z') && !dateBStr.contains('+')) dateBStr += '+08:00';

            DateTime dateA = DateTime.tryParse(dateAStr) ?? DateTime.utc(1970);
            DateTime dateB = DateTime.tryParse(dateBStr) ?? DateTime.utc(1970);
            
            return dateB.compareTo(dateA);
          });

          setState(() {
            documents = fetchedDocs;
            _applyFilters();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user documents: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredDocuments = documents.where((doc) {
        final title = (doc['title'] ?? '').toString().toLowerCase();
        final trackingId = (doc['qr_code'] ?? '').toString().toLowerCase();
        final matchesSearch = title.contains(_searchQuery.toLowerCase()) || trackingId.contains(_searchQuery.toLowerCase());

        String rawStatus = doc['status'] ?? 'pending';
        String docStatus = rawStatus.toLowerCase();
        
        bool matchesStatus = _selectedStatus == 'All Statuses' || docStatus == _selectedStatus.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Processing History'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
        : RefreshIndicator(
            onRefresh: fetchDocuments, // Pull-to-refresh
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildFilterDropdown(),
                  const SizedBox(height: 24),
                  
                  if (filteredDocuments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text("No documents found.", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...filteredDocuments.map((doc) => _buildHistoryCard(doc)),
                    
                  const SizedBox(height: 80),
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

  Widget _buildSearchBar() => TextField(
        onChanged: (value) {
          _searchQuery = value;
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: 'Search tracking ID or title...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      );

  Widget _buildFilterDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedStatus,
            items: [
              'All Statuses', 'Pending', 'In Verification', 'Signed', 
              'Action Required', 'Completed', 'Verified', 'Approved'
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedStatus = newValue;
                  _applyFilters();
                });
              }
            },
          ),
        ),
      );

  Widget _buildHistoryCard(Map<String, dynamic> doc) {
    final String trackingId = doc['qr_code'] ?? 'N/A';
    final String title = doc['title'] ?? 'No Title';
    final String category = doc['form_type'] ?? 'Document';
    
    final String rawStatus = doc['status'] ?? 'Pending';
    final String status = rawStatus.isEmpty ? 'Pending' : rawStatus[0].toUpperCase() + rawStatus.substring(1);

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'pending':
      case 'action required':
        statusColor = Colors.orange;
        break;
      case 'in verification':
      case 'verified':
        statusColor = Colors.blue;
        break;
      case 'signed':
      case 'approved':
      case 'completed':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    final List<dynamic> history = doc['history'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: Colors.red.shade50)
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(20),
          title: Text(
            '$trackingId: $title', 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(category, style: const TextStyle(fontSize: 14, color: Colors.black54))),
                Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
          ),
          children: [
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text("No scan history available.", style: TextStyle(color: Colors.grey)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Column(
                  children: List.generate(history.length, (index) {
                    final h = history[index];
                    final bool isLast = index == history.length - 1;
                    
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 12, 
                              height: 12,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryRed, 
                                shape: BoxShape.circle
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2, 
                                height: 60, 
                                color: Colors.red.shade100
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h['office'] ?? 'Unknown Office', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Action: ${h['action'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              Text('Date: ${h['timestamp'] ?? '--'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              if (!isLast) const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              )
          ],
        ),
      ),
    );
  }
}