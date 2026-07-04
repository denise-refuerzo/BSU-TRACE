// lib/screens/logistics_history_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/modals/history_gymnasium_modal.dart';
import '../config.dart';

class LogisticsHistoryScreen extends StatefulWidget {
  const LogisticsHistoryScreen({super.key});

  @override
  State<LogisticsHistoryScreen> createState() => _LogisticsHistoryScreenState();
}

class _LogisticsHistoryScreenState extends State<LogisticsHistoryScreen> {
  bool _isLendingActive = true;
  List<dynamic> bookings = [];
  List<dynamic> filteredBookings = [];
  bool isLoading = true;
  String _searchQuery = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchBookings();
    // 10-second background auto-refresh
    _timer = Timer.periodic(const Duration(seconds: 10), (t) => fetchBookings());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchBookings() async {
    final url = '${AppConfig.baseUrl}/scheduler/bookings';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            bookings = json.decode(response.body);
            _applyFilters();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching logistics history: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredBookings = bookings.where((b) {
        final requestor = (b['requestor'] ?? '').toString().toLowerCase();
        final asset = (b['destination'] ?? b['purpose'] ?? '').toString().toLowerCase();
        final status = (b['status'] ?? '').toString().toLowerCase();

        final matchesSearch = requestor.contains(_searchQuery.toLowerCase()) || asset.contains(_searchQuery.toLowerCase());
        
        // "Lending" implies active/reserved items. "Return" implies completed items.
        final matchesTab = _isLendingActive 
            ? status != 'completed' 
            : status == 'completed';

        return matchesSearch && matchesTab;
      }).toList();
    });
  }

  // Helper method to format raw DB dates without needing external intl packages
  String formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      DateTime d = DateTime.parse(dateString);
      List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (e) {
      return dateString.split('T')[0];
    }
  }

  String formatTime(String? timeString) {
    if (timeString == null) return 'N/A';
    try {
      final parts = timeString.split(':');
      int hour = int.parse(parts[0]);
      String min = parts[1];
      String period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12 == 0 ? 12 : hour % 12;
      return '${hour.toString().padLeft(2, '0')}:$min $period';
    } catch (e) {
      return timeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryRed),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Procurement Hub',
          style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Georgia'),
        ),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
        : RefreshIndicator(
            onRefresh: fetchBookings, // Pull-to-refresh
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Logistics History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), fontFamily: 'Georgia')),
                  const SizedBox(height: 20),
                  
                  TextField(
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search requestor or asset...',
                      hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white, 
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryRed)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() { _isLendingActive = true; _applyFilters(); }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: _isLendingActive ? AppTheme.primaryRed : Colors.transparent, borderRadius: BorderRadius.circular(7)),
                              child: Center(child: Text('Lending', style: TextStyle(color: _isLendingActive ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() { _isLendingActive = false; _applyFilters(); }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: !_isLendingActive ? AppTheme.primaryRed : Colors.transparent, borderRadius: BorderRadius.circular(7)),
                              child: Center(child: Text('Return', style: TextStyle(color: !_isLendingActive ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (filteredBookings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: Text("No history found for this category.", style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...filteredBookings.map((b) {
                      return _buildHistoryCard(
                        context: context,
                        category: b['booking_type']?.toString().toUpperCase() ?? 'LOGISTICS',
                        requestor: b['requestor'] ?? 'Unknown Requestor',
                        assetIcon: b['booking_type'] == 'Vehicle' ? Icons.directions_car : Icons.inventory_2_outlined,
                        assetText: b['destination'] ?? b['purpose'] ?? 'Asset',
                        date: formatDate(b['reservation_date']),
                        time: '${formatTime(b['start_time'])} - ${formatTime(b['end_time'])}',
                        status: (b['status'] ?? 'Pending').toString().toUpperCase(),
                        actionText: b['status'] == 'Completed' ? 'History Only' : 'View Details',
                        isActionable: b['status'] != 'Completed',
                      );
                    }),
                    
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildHistoryCard({
    required BuildContext context,
    required String category,
    required String requestor,
    required IconData assetIcon,
    required String assetText,
    required String date,
    required String time,
    required String status,
    required String actionText,
    required bool isActionable,
  }) {
    Color badgeBgColor = Colors.red.shade50;
    Color badgeTextColor = const Color(0xFFC62828);
    
    if (status == 'COMPLETED') {
      badgeBgColor = Colors.red.shade50.withValues(alpha: 0.5);
      badgeTextColor = Colors.black54;
    } else if (status == 'CONFIRMED' || status == 'APPROVED') {
      badgeBgColor = Colors.green.shade50;
      badgeTextColor = Colors.green.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(category, style: const TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(12)),
                child: Text(status, style: TextStyle(color: badgeTextColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Text(requestor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87)),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(assetIcon, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Expanded(child: Text(assetText, style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.black54),
              const SizedBox(width: 6),
              Text(date, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],
          ),
          
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade100, thickness: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(time, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500)),
              InkWell(
                onTap: isActionable ? () {
                  showDialog(
                    context: context,
                    builder: (context) => const HistoryGymnasiumModal(),
                  );
                } : null,
                child: Row(
                  children: [
                    Text(actionText, style: TextStyle(color: isActionable ? AppTheme.primaryRed : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    if (isActionable) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14, color: AppTheme.primaryRed),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}