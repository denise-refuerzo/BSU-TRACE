import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/modals/multimedia_reservation_modal.dart';
import '../config.dart';

class MultimediaRoomScreen extends StatefulWidget {
  const MultimediaRoomScreen({super.key});

  @override
  State<MultimediaRoomScreen> createState() => _MultimediaRoomScreenState();
}

class _MultimediaRoomScreenState extends State<MultimediaRoomScreen> {
  List<dynamic> bookings = [];
  List<dynamic> filteredBookings = [];
  bool isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All Statuses';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchMultimediaBookings();
    _timer = Timer.periodic(const Duration(seconds: 10), (t) => fetchMultimediaBookings());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchMultimediaBookings() async {
    final url = '${AppConfig.baseUrl}/scheduler/bookings';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            final allBookings = json.decode(response.body) as List;
            bookings = allBookings.where((b) => (b['booking_type'] ?? '').toString().toLowerCase() == 'room' || (b['booking_type'] ?? '').toString().toLowerCase() == 'multimedia room').toList();
            _applyFilters();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching multimedia room reservations: $e');
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
          style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : RefreshIndicator(
              onRefresh: fetchMultimediaBookings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Multimedia Room', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
                    const SizedBox(height: 4),
                    const Text('Manage and approve AV facility reservations.', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 20),
                    
                    TextField(
                      onChanged: (val) {
                        _searchQuery = val;
                        _applyFilters();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search requestor...',
                        hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.black54),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.primaryRed)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          items: ['All Statuses', 'Reserved', 'Confirmed', 'Completed']
                              .map((status) => DropdownMenuItem(value: status, child: Text(status, style: const TextStyle(color: Colors.black87, fontSize: 14))))
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
                        child: Center(child: Text('No multimedia room reservations found.', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...filteredBookings.map((b) {
                        final status = (b['status'] ?? 'Reserved').toString();
                        final dateStr = formatDate(b['reservation_date']);
                        
                        return _buildMultimediaCard(
                          context: context,
                          bookingData: b, // <-- PASSES THE DATA HERE
                          requestor: b['requestor'] ?? 'Unknown Requestor',
                          date: dateStr,
                          room: b['purpose'] ?? 'Multimedia Suite A',
                          status: status,
                          icon: Icons.videocam_outlined,
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  // Notice the addition of `required Map<String, dynamic> bookingData`
  Widget _buildMultimediaCard({
    required BuildContext context,
    required Map<String, dynamic> bookingData,
    required String requestor,
    required String date,
    required String room,
    required String status,
    required IconData icon,
  }) {
    Color badgeBgColor;
    Color badgeTextColor;
    Color dotColor;
    Color badgeBorderColor;

    final statusLower = status.toLowerCase();
    if (statusLower == 'reserved' || statusLower == 'pending') {
      badgeBgColor = const Color(0xFFFFF9C4);
      badgeTextColor = const Color(0xFFF57F17);
      dotColor = const Color(0xFFF57F17);
      badgeBorderColor = const Color(0xFFFFE082);
    } else if (statusLower == 'confirmed' || statusLower == 'approved') {
      badgeBgColor = const Color(0xFFE8F5E9);
      badgeTextColor = const Color(0xFF2E7D32);
      dotColor = const Color(0xFF2E7D32);
      badgeBorderColor = const Color(0xFFA5D6A7);
    } else {
      badgeBgColor = const Color(0xFFFCE4EC);
      badgeTextColor = const Color(0xFF5D4037);
      dotColor = const Color(0xFF5D4037);
      badgeBorderColor = const Color(0xFFF8BBD0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: AppTheme.primaryRed),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(requestor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('ROOM / PURPOSE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(room, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: badgeBorderColor, width: 0.5)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(status.toUpperCase(), style: TextStyle(color: badgeTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                // Passes the data to the modal
                final result = await showDialog(
                  context: context,
                  builder: (context) => MultimediaReservationModal(bookingData: bookingData),
                );
                if (result == true) {
                  fetchMultimediaBookings(); // Instantly refreshes on success
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppTheme.primaryRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('View Details', style: TextStyle(color: AppTheme.primaryRed, fontSize: 14)),
                  SizedBox(width: 8),
                  Icon(Icons.open_in_new, size: 16, color: AppTheme.primaryRed),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}