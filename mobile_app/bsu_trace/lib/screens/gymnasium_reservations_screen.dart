// lib/screens/gymnasium_reservations_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../widgets/modals/gymnasium_reservation_modal.dart';
import '../../config.dart';

class GymnasiumReservationsScreen extends StatefulWidget {
  const GymnasiumReservationsScreen({super.key});

  @override
  State<GymnasiumReservationsScreen> createState() => _GymnasiumReservationsScreenState();
}

class _GymnasiumReservationsScreenState extends State<GymnasiumReservationsScreen> {
  List<dynamic> bookings = [];
  List<dynamic> filteredBookings = [];
  bool isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All Statuses';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchGymBookings();
    _timer = Timer.periodic(const Duration(seconds: 10), (t) => fetchGymBookings());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchGymBookings() async {
    final url = '${AppConfig.baseUrl}/scheduler/bookings';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            final allBookings = json.decode(response.body) as List;
            bookings = allBookings.where((b) => (b['booking_type'] ?? '').toString().toLowerCase() == 'gymnasium').toList();
            _applyFilters();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching gymnasium reservations: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredBookings = bookings.where((b) {
        final requestor = (b['requestor'] ?? '').toString().toLowerCase();
        final purpose = (b['purpose'] ?? '').toString().toLowerCase();
        final status = (b['status'] ?? 'Reserved').toString().toLowerCase();

        final matchesSearch = requestor.contains(_searchQuery.toLowerCase()) || purpose.contains(_searchQuery.toLowerCase());
        final matchesStatus = _selectedStatus == 'All Statuses' || status == _selectedStatus.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

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
    if (timeString == null) return '';
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
          style: TextStyle(
            color: AppTheme.primaryRed,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Georgia',
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : RefreshIndicator(
              onRefresh: fetchGymBookings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gymnasium Reservations',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), fontFamily: 'Georgia'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage and approve court booking requests for university events.',
                      style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    
                    TextField(
                      onChanged: (val) {
                        _searchQuery = val;
                        _applyFilters();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by requestor...',
                        hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.black54),
                        filled: true,
                        fillColor: Colors.red.shade50.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.red.shade100)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.primaryRed)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          items: ['All Statuses', 'Reserved', 'Confirmed', 'Completed']
                              .map((status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStatus = val;
                                _applyFilters();
                              });
                            }
                          },
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (filteredBookings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: Text('No gymnasium reservations found.', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...filteredBookings.map((b) {
                        final status = (b['status'] ?? 'Reserved').toString().toUpperCase();
                        final dateStr = formatDate(b['reservation_date']);
                        final timeStr = b['start_time'] != null ? ' | ${formatTime(b['start_time'])}' : '';
                        return _buildGymCard(
                          context: context,
                          requestor: b['requestor'] ?? 'Unknown Requestor',
                          details: '${b['purpose'] ?? 'Court Booking'} | $dateStr$timeStr',
                          status: status,
                          icon: Icons.sports_basketball,
                          iconColor: AppTheme.primaryRed,
                          iconBgColor: Colors.red.shade50,
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGymCard({
    required BuildContext context,
    required String requestor,
    required String details,
    required String status,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    Color statusBgColor = Colors.red.shade50;
    Color statusTextColor = AppTheme.primaryRed;

    if (status == 'CONFIRMED') {
      statusBgColor = Colors.green.shade50;
      statusTextColor = Colors.green.shade800;
    } else if (status == 'COMPLETED') {
      statusBgColor = Colors.grey.shade200;
      statusTextColor = Colors.black54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(requestor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87, fontFamily: 'Georgia')),
                    const SizedBox(height: 4),
                    Text(details, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(16)),
                child: Text(status, style: TextStyle(color: statusTextColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const GymnasiumReservationModal(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}