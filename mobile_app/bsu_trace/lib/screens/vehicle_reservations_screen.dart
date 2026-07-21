import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/modals/vehicle_reservation_modal.dart';
import '../config.dart';

class VehicleReservationsScreen extends StatefulWidget {
  const VehicleReservationsScreen({super.key});

  @override
  State<VehicleReservationsScreen> createState() => _VehicleReservationsScreenState();
}

class _VehicleReservationsScreenState extends State<VehicleReservationsScreen> {
  List<dynamic> bookings = [];
  List<dynamic> filteredBookings = [];
  bool isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All Statuses';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchVehicleBookings();
    _timer = Timer.periodic(const Duration(seconds: 10), (t) => fetchVehicleBookings());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchVehicleBookings() async {
    final url = '${AppConfig.baseUrl}/scheduler/bookings';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            final allBookings = json.decode(response.body) as List;
            bookings = allBookings.where((b) => (b['booking_type'] ?? '').toString().toLowerCase() == 'vehicle').toList();
            _applyFilters();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching vehicle reservations: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredBookings = bookings.where((b) {
        final requestor = (b['requestor'] ?? '').toString().toLowerCase();
        final vehicle = (b['destination'] ?? b['purpose'] ?? '').toString().toLowerCase();
        final status = (b['status'] ?? 'Reserved').toString().toLowerCase();

        final matchesSearch = requestor.contains(_searchQuery.toLowerCase()) || vehicle.contains(_searchQuery.toLowerCase());
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
          style: TextStyle(
            color: AppTheme.primaryRed,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : RefreshIndicator(
              onRefresh: fetchVehicleBookings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Reservations',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage and track fleet requests',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    
                    TextField(
                      onChanged: (val) {
                        _searchQuery = val;
                        _applyFilters();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search requestor or vehicle...',
                        hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.black54),
                        filled: true,
                        fillColor: AppTheme.scaffoldBg,
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
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.scaffoldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          items: ['All Statuses', 'Reserved', 'Confirmed', 'Completed']
                              .map((status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
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
                    const SizedBox(height: 20),

                    if (filteredBookings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: Text('No vehicle reservations found.', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...filteredBookings.map((b) {
                        final status = (b['status'] ?? 'Reserved').toString().toUpperCase();
                        final dateStr = '${formatDate(b['reservation_date'])} | ${formatTime(b['start_time'])} -\n${formatTime(b['end_time'])}';
                        
                        return _buildReservationCard(
                          context: context,
                          bookingData: b, // <-- PASSES THE DATA HERE
                          requestor: b['requestor'] ?? 'Unknown Requestor',
                          vehicle: b['destination'] ?? b['purpose'] ?? 'Vehicle',
                          date: dateStr,
                          status: status,
                          icon: Icons.directions_car_outlined,
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  // Notice the addition of `required Map<String, dynamic> bookingData`
  Widget _buildReservationCard({
    required BuildContext context,
    required Map<String, dynamic> bookingData,
    required String requestor,
    required String vehicle,
    required String date,
    required String status,
    required IconData icon,
  }) {
    final bool isReserved = status == 'RESERVED' || status == 'PENDING';
    final Color statusTextColor = isReserved ? AppTheme.primaryRed : Colors.black54;
    final Color statusBgColor = isReserved ? Colors.red.shade50 : Colors.grey.shade300;
    final Color statusBorderColor = isReserved ? Colors.red.shade100 : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          // Passes the data to the modal
          final result = await showDialog(
            context: context,
            builder: (context) => VehicleReservationModal(bookingData: bookingData), 
          );
          if (result == true) {
            fetchVehicleBookings(); // Instantly refreshes on success
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: AppTheme.primaryRed),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(requestor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                        const SizedBox(height: 4),
                        Text('VEHICLE: $vehicle', style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: statusBorderColor)),
                    child: Text(status, style: TextStyle(color: statusTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(date, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4))),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('VIEW', style: TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('DETAILS', style: TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryRed)
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}