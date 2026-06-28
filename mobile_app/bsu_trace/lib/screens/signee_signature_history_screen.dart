// lib/screens/signee_signature_history_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/signee_history_details_modal.dart';
import '../config.dart';

class SigneeSignatureHistoryScreen extends StatefulWidget {
  const SigneeSignatureHistoryScreen({super.key});

  @override
  State<SigneeSignatureHistoryScreen> createState() => _SigneeSignatureHistoryScreenState();
}

class _SigneeSignatureHistoryScreenState extends State<SigneeSignatureHistoryScreen> {
  List<dynamic> allDocuments = [];
  List<dynamic> filteredDocuments = [];
  bool isLoading = true;
  Timer? _timer;

  String _searchQuery = '';
  String _selectedStatus = 'All Statuses';

  // --- Pagination State ---
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    fetchDocuments();
    
    // 10-second silent background auto-refresh
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
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/documents'));
      
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
            
            return dateB.compareTo(dateA); // Newest first
          });

          setState(() {
            allDocuments = fetchedDocs;
            _applyFilters();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching signature history: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredDocuments = allDocuments.where((doc) {
        final title = (doc['title'] ?? '').toString().toLowerCase();
        final trackingId = (doc['qr_code'] ?? '').toString().toLowerCase();
        final matchesSearch = title.contains(_searchQuery.toLowerCase()) || trackingId.contains(_searchQuery.toLowerCase());

        String rawStatus = doc['status'] ?? 'pending';
        String docStatus = rawStatus.toLowerCase();
        
        bool matchesStatus = _selectedStatus == 'All Statuses' || docStatus == _selectedStatus.toLowerCase();

        // For history, we only want to show documents that have already been processed
        bool isProcessed = ['signed', 'completed', 'verified', 'approved', 'sent back', 'archived'].contains(docStatus);
        
        return matchesSearch && matchesStatus && isProcessed;
      }).toList();

      _currentPage = 1; // Reset pagination on filter change
    });
  }

  // Force UTC+8 alignment to prevent emulator/device timezone bugs
  String formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      String normalizedTime = dateString.replaceAll(' ', 'T');
      if (!normalizedTime.endsWith('Z') && !normalizedTime.contains('+')) {
        normalizedTime += '+08:00';
      }
      
      DateTime parsedDate = DateTime.parse(normalizedTime);
      DateTime dPht = parsedDate.toUtc().add(const Duration(hours: 8));

      List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dPht.month - 1]} ${dPht.day.toString().padLeft(2, '0')}, ${dPht.year}';
    } catch (e) {
      return dateString.split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Pagination Calculation Logic ---
    int totalPages = (filteredDocuments.length / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    
    if (_currentPage > totalPages) _currentPage = totalPages;

    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > filteredDocuments.length) endIndex = filteredDocuments.length;

    List<dynamic> displayDocs = filteredDocuments.isEmpty 
        ? [] 
        : filteredDocuments.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Signature History'),
        actions: buildAppBarActions(context), // No refresh button added here
      ),
      drawer: const AppDrawer(),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
        : RefreshIndicator(
            onRefresh: fetchDocuments, // Swipe down to pull-to-refresh
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Processed Documents',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  TextField(
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by title or ID...',
                      hintStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: const Icon(Icons.search, color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red.shade100),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primaryRed),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Filter Dropdown
                  const Text(
                    'Filter by Status', 
                    style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedStatus,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                        items: [
                          'All Statuses', 'Signed', 'Verified', 'Approved', 'Completed', 'Sent Back'
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
                  ),
                  const SizedBox(height: 24),
                  
                  if (displayDocs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text("No processed documents found.", style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else ...[
                    ...displayDocs.map((doc) => _buildHistoryCard(context: context, document: doc)),
                    
                    // Pagination Controls UI
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? AppTheme.primaryRed : Colors.grey),
                              onPressed: _currentPage > 1 ? () {
                                setState(() { _currentPage--; });
                              } : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Page $_currentPage of $totalPages',
                                style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right, color: _currentPage < totalPages ? AppTheme.primaryRed : Colors.grey),
                              onPressed: _currentPage < totalPages ? () {
                                setState(() { _currentPage++; });
                              } : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                  
                  const SizedBox(height: 60), 
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildHistoryCard({required BuildContext context, required Map<String, dynamic> document}) {
    final String id = document['qr_code'] ?? 'N/A';
    final String title = document['title'] ?? 'No Title';
    final String formType = (document['form_type'] ?? 'Document').toString().toUpperCase();
    final String date = formatDate(document['created_at'] ?? document['updated_at']);
    
    final String rawStatus = document['status'] ?? 'Processed';
    final String status = rawStatus.isEmpty ? 'Processed' : rawStatus[0].toUpperCase() + rawStatus.substring(1);

    Color statusColor;
    if (['signed', 'approved', 'completed', 'verified'].contains(status.toLowerCase())) {
      statusColor = Colors.green;
    } else if (status.toLowerCase() == 'sent back') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300), // Muted border for history
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: $id', style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () {
                  // Trigger the history-specific modal
                  showDialog(
                    context: context,
                    builder: (context) => SigneeHistoryDetailsModal(document: document),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.remove_red_eye_outlined, color: Colors.black54, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3)),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            child: Text(
              'FORM: $formType',
              style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              Text(date, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}