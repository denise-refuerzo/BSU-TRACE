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
  List<dynamic> timelineEvents = [];
  List<dynamic> filteredEvents = [];
  bool isLoading = true;
  Timer? _timer;
  
  String _searchQuery = '';
  String _selectedAction = 'All'; // 'All', 'In Verification', 'Verified'

  @override
  void initState() {
    super.initState();
    fetchTimeline();
    // 10-second background auto-refresh
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) fetchTimeline();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchTimeline() async {
    final userId = SessionManager().userId;
    if (userId == null) return;

    final String url = '${AppConfig.baseUrl}/users/$userId/processing-timeline';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          List<dynamic> fetchedEvents = json.decode(response.body);

          // Sort by the time it was scanned in (newest first)
          fetchedEvents.sort((a, b) {
            String dateAStr = a['time_in'] ?? '1970-01-01T00:00:00+08:00';
            String dateBStr = b['time_in'] ?? '1970-01-01T00:00:00+08:00';

            dateAStr = dateAStr.replaceAll(' ', 'T');
            if (!dateAStr.endsWith('Z') && !dateAStr.contains('+')) dateAStr += '+08:00';

            dateBStr = dateBStr.replaceAll(' ', 'T');
            if (!dateBStr.endsWith('Z') && !dateBStr.contains('+')) dateBStr += '+08:00';

            DateTime dateA = DateTime.tryParse(dateAStr) ?? DateTime.utc(1970);
            DateTime dateB = DateTime.tryParse(dateBStr) ?? DateTime.utc(1970);
            
            return dateB.compareTo(dateA);
          });

          setState(() {
            timelineEvents = fetchedEvents;
            _applyFilters();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching processing timeline: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredEvents = timelineEvents.where((event) {
        final title = (event['title'] ?? '').toString().toLowerCase();
        final trackingId = (event['qr_code'] ?? '').toString().toLowerCase();
        final matchesSearch = title.contains(_searchQuery.toLowerCase()) || trackingId.contains(_searchQuery.toLowerCase());

        // Status Logic
        bool isVerified = event['time_out'] != null;
        bool matchesStatus = true;
        
        if (_selectedAction == 'In Verification') matchesStatus = !isVerified;
        if (_selectedAction == 'Verified') matchesStatus = isVerified;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Pending...';
    try {
      final DateTime dt = DateTime.parse(isoString).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$month ${dt.day}, ${dt.year} - $hour:$minute $ampm';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Scanning Timeline'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
        : RefreshIndicator(
            onRefresh: fetchTimeline,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildFilterDropdown(),
                  const SizedBox(height: 24),
                  
                  if (filteredEvents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text("No scanning records found.", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...filteredEvents.map((event) => _buildRecordCard(event)),
                    
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
            value: _selectedAction,
            items: ['All', 'In Verification', 'Verified']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedAction = newValue;
                  _applyFilters();
                });
              }
            },
          ),
        ),
      );

  Widget _buildRecordCard(Map<String, dynamic> event) {
    final String trackingId = event['qr_code'] ?? 'N/A';
    final String title = event['title'] ?? 'No Title';
    final String category = event['form_type'] ?? 'Document';
    
    final String? timeInStr = event['time_in'];
    final String? timeOutStr = event['time_out'];
    final bool isVerified = timeOutStr != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8), 
        border: Border(left: BorderSide(
          color: isVerified ? Colors.blue : Colors.orange, 
          width: 4
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$trackingId: $title', 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isVerified ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isVerified ? 'Verified' : 'In Verification',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? Colors.blue : Colors.orange.shade800,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(category, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),

          Row(
            children: [
              const Icon(Icons.login, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Scanned In:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(_formatDate(timeInStr), style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],
          ),
          
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.logout, size: 16, color: isVerified ? Colors.blue : Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Scanned Out:', 
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w500,
                  color: isVerified ? Colors.black : Colors.grey,
                )
              ),
              const Spacer(),
              Text(
                _formatDate(timeOutStr), 
                style: TextStyle(
                  fontSize: 13, 
                  color: isVerified ? Colors.black87 : Colors.grey,
                  fontStyle: isVerified ? FontStyle.normal : FontStyle.italic
                )
              ),
            ],
          ),
        ],
      ),
    );
  }
}