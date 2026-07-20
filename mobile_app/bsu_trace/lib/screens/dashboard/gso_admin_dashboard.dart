import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/document_scanner_modal.dart';
import '../../services/session_manager.dart';
import '../../models/user_role.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  int _totalDocuments = 0;
  int _incomingCount = 0;
  int _pendingCount = 0;
  int _archivedCount = 0;
  int _completedCount = 0;
  int _vehicleReservationsCount = 0;
  int _gymReservationsCount = 0;
  int _multimediaReservationsCount = 0;
  int _chairsCount = 0;
  int _tablesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final session = SessionManager();
      final token = session.sessionToken;
      final userId = session.userId;
      if (userId == null) return;
      final gsoResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/gso/$userId/dashboard-data'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final bookingsResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/scheduler/bookings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final inventoryResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/scheduler/inventory'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (gsoResponse.statusCode == 200) {
        final data = jsonDecode(gsoResponse.body);
        final metrics = data['metrics'] ?? {};
        if (mounted) {
          setState(() {
            _totalDocuments = metrics['total_documents'] ?? 0;
            _incomingCount = metrics['incoming'] ?? 0;
            _pendingCount = metrics['pending'] ?? 0;
            _archivedCount = metrics['archived'] ?? 0;
            _completedCount = metrics['completed'] ?? 0;
          });
        }
      }
      if (bookingsResponse.statusCode == 200) {
        final List<dynamic> bookings = jsonDecode(bookingsResponse.body);
        int vehicles = bookings.where((b) => b['booking_type']?.toString().toLowerCase() == 'vehicle').length;
        int gym = bookings.where((b) => b['booking_type']?.toString().toLowerCase() == 'gymnasium').length;
        int multimedia = bookings.where((b) => b['booking_type']?.toString().toLowerCase() == 'room' || b['booking_type']?.toString().toLowerCase() == 'multimedia room').length;
        if (mounted) {
          setState(() {
            _vehicleReservationsCount = vehicles;
            _gymReservationsCount = gym;
            _multimediaReservationsCount = multimedia;
          });
        }
      }
      if (inventoryResponse.statusCode == 200) {
        final List<dynamic> inventory = jsonDecode(inventoryResponse.body);
        int chairs = 0;
        int tables = 0;
        for (var item in inventory) {
          String name = item['asset_name']?.toString().toLowerCase() ?? '';
          int totalQty = item['total'] ?? item['capacity'] ?? 0;
          if (name.contains('chair')) {
            chairs = totalQty;
          } else if (name.contains('table')) {
            tables = totalQty;
          }
        }
        if (mounted) {
          setState(() {
            _chairsCount = chairs;
            _tablesCount = tables;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching GSO dashboard metrics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load GSO dashboard metrics.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = SessionManager().currentRole;
    if (role != UserRole.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('GSO Dashboard'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : RefreshIndicator(
              color: AppTheme.primaryRed,
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DOCUMENT METRICS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRed,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalDocumentsCard(),
                        const SizedBox(width: 12),
                        _buildSmallMetricsGrid(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'FACILITY & ASSET COUNTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRed,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildReservationsAndInventoryGrid(),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.document_scanner_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildTotalDocumentsCard() {
    return Expanded(
      flex: 1,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, color: Colors.white, size: 40),
            const SizedBox(height: 16),
            Text(
              _totalDocuments.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'TOTAL DOCUMENTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallMetricsGrid() {
    return Expanded(
      flex: 1,
      child: Column(
        children: [
          Row(
            children: [
              _buildMetric('$_incomingCount', 'INCOMING', Icons.downloading, Colors.blue.shade50),
              const SizedBox(width: 12),
              _buildMetric('$_pendingCount', 'PENDING', Icons.assignment_late, Colors.orange.shade50),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetric('$_archivedCount', 'ARCHIVED (ACTION REQ)', Icons.archive, Colors.red.shade50),
              const SizedBox(width: 12),
              _buildMetric('$_completedCount', 'COMPLETED', Icons.check_circle, Colors.green.shade50),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label, IconData icon, Color bg) {
    return Expanded(
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade50),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 6.5,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationsAndInventoryGrid() {
    return Column(
      children: [
        Row(
          children: [
            _buildCountCard('$_vehicleReservationsCount', 'VEHICLE RESERVATIONS', Icons.directions_bus, Colors.blue.shade700),
            const SizedBox(width: 12),
            _buildCountCard('$_gymReservationsCount', 'GYM RESERVATIONS', Icons.sports_basketball, Colors.orange.shade700),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCountCard('$_multimediaReservationsCount', 'MULTIMEDIA RESERVATIONS', Icons.co_present, Colors.purple.shade700),
            const SizedBox(width: 12),
            _buildCountCard('$_chairsCount', 'STACKABLE CHAIRS', Icons.chair, Colors.teal.shade700),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCountCard('$_tablesCount', 'FOLDING TABLES', Icons.table_restaurant, Colors.brown.shade700),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildCountCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}