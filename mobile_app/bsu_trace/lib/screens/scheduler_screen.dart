// lib/screens/scheduler_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../screens/ai_chat_screen.dart';
import '../theme/app_theme.dart'; 
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/new_request_modal.dart';
import '../config.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  bool _isLoading = true;
  List<dynamic> _allBookings = [];
  List<dynamic> _inventory = [];
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _fetchSchedulerData();
    
    // Background polling for live sync
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchSchedulerData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSchedulerData({bool isBackground = false}) async {
    try {
      final bookingsRes = await http.get(Uri.parse('${AppConfig.baseUrl}/scheduler/bookings'));
      final inventoryRes = await http.get(Uri.parse('${AppConfig.baseUrl}/scheduler/inventory'));

      if (bookingsRes.statusCode == 200 && inventoryRes.statusCode == 200 && mounted) {
        setState(() {
          _allBookings = json.decode(bookingsRes.body);
          _inventory = json.decode(inventoryRes.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching scheduler data: $e');
    } finally {
      if (!isBackground && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Resource Scheduler', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
          actions: buildAppBarActions(context),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryRed,
            labelColor: AppTheme.primaryRed,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Vehicles'),
              Tab(text: 'Multimedia Room'),
              Tab(text: 'Gymnasium'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : TabBarView(
          children: [
            // Passed down the refresh function as a callback
            SchedulerContent(
              category: 'Vehicle', 
              bookings: _allBookings, 
              inventory: _inventory,
              onRefresh: () => _fetchSchedulerData(isBackground: true)
            ),
            SchedulerContent(
              category: 'Multimedia Room', 
              bookings: _allBookings, 
              inventory: _inventory,
              onRefresh: () => _fetchSchedulerData(isBackground: true)
            ),
            SchedulerContent(
              category: 'Gymnasium', 
              bookings: _allBookings, 
              inventory: _inventory,
              onRefresh: () => _fetchSchedulerData(isBackground: true)
            ),
          ],
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 1. The New AI Chat Button
            FloatingActionButton.extended(
              heroTag: 'ai_chat_btn', // Required when using multiple FABs
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AiChatScreen()),
                );
              },
              backgroundColor: Colors.blue.shade800,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text('Ask AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(width: 16), // Spacing between the buttons
            
            // 2. Your Existing Add Document Button
            FloatingActionButton.extended(
                  onPressed: () {
                    showDialog(
                      context: context, 
                      builder: (context) => const NewRequestModal(),
                    );
                  },
              backgroundColor: Colors.red.shade700, 
              icon: const Icon(Icons.post_add, color: Colors.white),
              label: const Text('New Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      )
    );
  }
}

class SchedulerContent extends StatefulWidget {
  final String category;
  final List<dynamic> bookings;
  final List<dynamic> inventory;
  final Future<void> Function() onRefresh;

  const SchedulerContent({
    super.key, 
    required this.category, 
    required this.bookings, 
    required this.inventory,
    required this.onRefresh
  });

  @override
  State<SchedulerContent> createState() => _SchedulerContentState();
}

class _SchedulerContentState extends State<SchedulerContent> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now(); 
  }

  // Filters the global bookings down to the current tab and current viewed month
  List<dynamic> get _filteredBookings {
    return widget.bookings.where((b) {
      if (b['booking_type'] != widget.category) return false;
      
      if (b['reservation_date'] == null) return false;
      final date = DateTime.parse(b['reservation_date']).toLocal();
      return date.year == _currentMonth.year && date.month == _currentMonth.month;
    }).toList();
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'TBA';
    try {
      final parts = timeStr.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      String ampm = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
    } catch (e) {
      return timeStr;
    }
  }

  // Pops up a dialog listing all the events for the tapped day
  void _showDayEventsDialog(BuildContext context, int day, List<dynamic> dayBookings) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${months[_currentMonth.month - 1]} $day, ${_currentMonth.year}';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.scaffoldBg,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Events for $dateStr', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: dayBookings.map((event) => _buildEventItem(
                        context,
                        widget.category.toUpperCase(),
                        _formatTime(event['start_time']),
                        event['purpose'] ?? 'Untitled Booking',
                        event['department'] ?? 'General',
                        event
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBookings = _filteredBookings;

    return RefreshIndicator(
      color: AppTheme.primaryRed,
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendarHeader(),
            const SizedBox(height: 16),
            _buildCalendarGrid(activeBookings),
            const SizedBox(height: 24),
            Text('Scheduled Events (${widget.category})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            if (activeBookings.isEmpty)
              const Text('No events scheduled for this month.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              
            ...activeBookings.map((event) => _buildEventItem(
              context,
              widget.category.toUpperCase(),
              _formatTime(event['start_time']),
              event['purpose'] ?? 'Untitled Booking',
              event['department'] ?? 'General',
              event
            )),
            
            const SizedBox(height: 24),
            _buildInventorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('${months[_currentMonth.month - 1]} ${_currentMonth.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Row(children: [
          IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
        ])
      ],
    );
  }

  Widget _buildCalendarGrid(List<dynamic> activeBookings) {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    int daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: days.map((d) => Text(d, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))).toList()),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: daysInMonth, 
          itemBuilder: (context, index) {
            int day = index + 1;
            
            // Gather all bookings mapped to this specific day
            List<dynamic> dayBookings = activeBookings.where((b) {
              if (b['reservation_date'] == null) return false;
              final date = DateTime.parse(b['reservation_date']).toLocal();
              return date.day == day;
            }).toList();
            
            // Update: Red if Reserved, Green if Confirmed
            bool hasReserved = dayBookings.any((b) => (b['status'] ?? '').toString().toLowerCase() == 'reserved');
            bool hasConfirmed = dayBookings.any((b) => (b['status'] ?? '').toString().toLowerCase() == 'confirmed');

            Color bgColor = Colors.transparent;
            Color borderColor = Colors.transparent;

            // Give visual priority to Red (Action Needed / Reserved)
            if (hasReserved) {
              bgColor = AppTheme.primaryRed.withValues(alpha: 0.2);
              borderColor = AppTheme.primaryRed;
            } else if (hasConfirmed) {
              bgColor = Colors.green.withValues(alpha: 0.2);
              borderColor = Colors.green;
            }

            return GestureDetector(
              onTap: dayBookings.isNotEmpty ? () {
                _showDayEventsDialog(context, day, dayBookings);
              } : null,
              child: Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: borderColor != Colors.transparent ? Border.all(color: borderColor) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$day', style: TextStyle(fontWeight: dayBookings.isNotEmpty ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEventItem(BuildContext context, String type, String time, String title, String dept, Map<String, dynamic> eventData) {
    return GestureDetector(
      onTap: () {
        showDialog(context: context, builder: (context) => EventDetailsDialog(eventData: eventData));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type, style: TextStyle(fontSize: 10, color: Colors.blue.shade300, fontWeight: FontWeight.bold)),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(dept, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    int chairsTotal = 400; 
    int chairsInUse = 0;
    
    int tablesTotal = 120;
    int tablesInUse = 0;
    
    for (var item in widget.inventory) {
      if (item['asset_name'] == 'Stackable Chairs') {
        chairsTotal = item['total'] ?? chairsTotal;
        chairsInUse = item['in_use'] ?? 0;
      }
      if (item['asset_name'] == 'Folding Table') {
        tablesTotal = item['total'] ?? tablesTotal;
        tablesInUse = item['in_use'] ?? 0;
      }
    }

    int chairsAvailable = (chairsTotal - chairsInUse).clamp(0, chairsTotal);
    int tablesAvailable = (tablesTotal - tablesInUse).clamp(0, tablesTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Logistics Inventory (Today)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildInventoryBar('Folding Tables', tablesAvailable, tablesTotal),
        const SizedBox(height: 12),
        _buildInventoryBar('Stackable Chairs', chairsAvailable, chairsTotal),
      ],
    );
  }

  Widget _buildInventoryBar(String title, int available, int total) {
    double availabilityRatio = total > 0 ? (available / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Text(title), 
            Text('$available available', style: const TextStyle(fontWeight: FontWeight.bold))
          ]
        ),
        const SizedBox(height: 6), 
        LinearProgressIndicator(
          value: availabilityRatio, 
          color: AppTheme.primaryRed, 
          backgroundColor: Colors.grey.shade200
        ),
      ],
    );
  }
}

class EventDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> eventData;

  const EventDetailsDialog({super.key, required this.eventData});

  String _formatDateTime(String? isoDate, String? time) {
    if (isoDate == null) return 'Unknown Date';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formattedDate = '${months[date.month - 1]} ${date.day}, ${date.year}';
      
      String formattedTime = 'TBA';
      if (time != null) {
        final parts = time.split(':');
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        String ampm = h >= 12 ? 'PM' : 'AM';
        h = h % 12;
        if (h == 0) h = 12;
        formattedTime = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
      }
      
      return '$formattedDate • $formattedTime';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = eventData['purpose'] ?? 'Untitled Booking';
    String requestor = eventData['requestor'] ?? 'Unknown';
    String department = eventData['department'] ?? 'General';
    String timeString = _formatDateTime(eventData['reservation_date'], eventData['start_time']);
    
    String extraNote = eventData['destination'] != null ? 'Destination: ${eventData['destination']}' : 'Standard Equipment provided';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Event Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(timeString, style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildDetailRow('REQUESTOR', requestor),
                _buildDetailRow('DEPARTMENT', department),
                _buildDetailRow('STATUS', (eventData['status'] ?? 'Unknown').toUpperCase()),
                _buildDetailRow('NOTES / DESTINATION', extraNote),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white),
                    child: const Text('Acknowledge'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}