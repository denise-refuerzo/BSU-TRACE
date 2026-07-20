import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/modals/admin_document_details_modal.dart';
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

  // GSO Office Specific Document Metrics
  int _totalDocuments = 0;
  int _incomingCount = 0;
  int _pendingCount = 0;
  int _awaitingScanInCount = 0;
  int _completedCount = 0;

  // GSO Module Pending Reservation Stats
  int _pendingVehicles = 0;
  int _pendingGymnasium = 0;
  int _pendingMultimedia = 0;

  // Filtered GSO Documents List & Pagination State
  List<dynamic> _gsoDocuments = [];
  int _currentPage = 1;
  final int _rowsPerPage = 5;

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

      // 1. Fetch office-isolated documents for this GSO Admin
      final docsResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/processors/$userId/documents'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // 2. Fetch all bookings for GSO reservation cards
      final bookingsResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/scheduler/bookings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (docsResponse.statusCode == 200) {
        final List<dynamic> documents = jsonDecode(docsResponse.body);

        int total = documents.length;
        int completed = documents.where((d) => d['status']?.toString().toLowerCase() == 'completed').length;
        int pending = documents.where((d) => d['status']?.toString().toLowerCase() == 'pending').length;
        int incoming = documents.where((d) => d['is_at_current_office'] == true && d['time_in'] == null).length;
        int awaitingScanIn = documents.where((d) => d['time_in'] == null).length;

        if (mounted) {
          setState(() {
            _totalDocuments = total;
            _completedCount = completed;
            _pendingCount = pending;
            _incomingCount = incoming;
            _awaitingScanInCount = awaitingScanIn;
            _gsoDocuments = documents;
            _currentPage = 1; // Reset to page 1 on refresh
          });
        }
      }

      if (bookingsResponse.statusCode == 200) {
        final List<dynamic> bookings = jsonDecode(bookingsResponse.body);

        int vehicles = bookings.where((b) => 
          b['booking_type']?.toString().toLowerCase() == 'vehicle' && 
          b['status']?.toString().toLowerCase() == 'reserved'
        ).length;

        int gymnasium = bookings.where((b) => 
          b['booking_type']?.toString().toLowerCase() == 'gymnasium' && 
          b['status']?.toString().toLowerCase() == 'reserved'
        ).length;

        int multimedia = bookings.where((b) => 
          (b['booking_type']?.toString().toLowerCase() == 'room' || 
           b['booking_type']?.toString().toLowerCase() == 'multimedia room') && 
          b['status']?.toString().toLowerCase() == 'reserved'
        ).length;

        if (mounted) {
          setState(() {
            _pendingVehicles = vehicles;
            _pendingGymnasium = gymnasium;
            _pendingMultimedia = multimedia;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching GSO dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load GSO dashboard data.')),
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
    // GATEKEEPER
    final role = SessionManager().currentRole;
    if (role != UserRole.admin && role != UserRole.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
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
                    // --- DOCUMENT METRICS ROW ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalDocumentsCard(),
                        const SizedBox(width: 12),
                        _buildSmallMetricsGrid(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- GSO FUNCTIONAL MODULES SECTION ---
                    const Text(
                      'GSO MODULES & RESERVATIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRed,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildGsoModulesGrid(context),
                    const SizedBox(height: 24),

                    // --- GSO ROUTED DOCUMENTS TABLE ---
                    _buildRecentDocumentsTable(context),
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
              'GSO ROUTED DOCS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
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
              _buildMetric('$_awaitingScanInCount', 'AWAITING SCAN IN', Icons.qr_code_scanner, Colors.grey.shade200),
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
        padding: const EdgeInsets.all(8),
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
                fontSize: 7,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGsoModulesGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildGsoCard(
              context,
              '$_pendingVehicles',
              'VEHICLES',
              Icons.directions_bus,
              Colors.blue.shade50,
              Colors.blue,
              '/vehicle_reservations',
            ),
            const SizedBox(width: 12),
            _buildGsoCard(
              context,
              '$_pendingGymnasium',
              'GYMNASIUM',
              Icons.sports_basketball,
              Colors.orange.shade50,
              Colors.orange,
              '/gymnasium_reservations',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildGsoCard(
              context,
              '$_pendingMultimedia',
              'MULTIMEDIA',
              Icons.co_present,
              Colors.purple.shade50,
              Colors.purple,
              '/multimedia_room',
            ),
            const SizedBox(width: 12),
            _buildGsoCard(
              context,
              'Manage',
              'ASSET REGISTRY',
              Icons.inventory,
              Colors.green.shade50,
              Colors.green,
              '/asset_registry',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGsoCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor,
    String route,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, route).then((_) => _fetchDashboardData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
      ),
    );
  }

  Widget _buildRecentDocumentsTable(BuildContext context) {
    final int totalPages = _gsoDocuments.isEmpty 
        ? 1 
        : (_gsoDocuments.length / _rowsPerPage).ceil();

    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }

    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final paginatedDocs = _gsoDocuments.skip(startIndex).take(_rowsPerPage).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GSO Routed Documents & Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Page $_currentPage of $totalPages',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'TITLE & QR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'GSO STATUS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'ACTION',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                )
              ],
            ),
          ),
          if (_gsoDocuments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No documents routed through GSO found.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...paginatedDocs.map((doc) => _buildDocRow(
                  context,
                  doc,
                )),
          
          if (_gsoDocuments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  
                  ...List.generate(totalPages, (index) {
                    final pageNum = index + 1;
                    final isSelected = pageNum == _currentPage;
                    return GestureDetector(
                      onTap: () => setState(() => _currentPage = pageNum),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryRed : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$pageNum',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _currentPage < totalPages
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildDocRow(BuildContext context, dynamic doc) {
    final title = doc['title'] ?? 'Unknown';
    final qrCode = doc['qr_code'] ?? 'N/A';
    final status = doc['status'] ?? 'AWAITING GSO ROUTE';
    
    Color badgeColor = Colors.orange;
    Color badgeBg = Colors.orange.shade50;
    if (status.toString().toLowerCase() == 'completed') {
      badgeColor = Colors.green;
      badgeBg = Colors.green.shade50;
    } else if (status.toString().toLowerCase() == 'signed' || status.toString().toLowerCase() == 'approved') {
      badgeColor = Colors.blue;
      badgeBg = Colors.blue.shade50;
    } else if (status.toString().toLowerCase() == 'awaiting gso route') {
      badgeColor = Colors.grey;
      badgeBg = Colors.grey.shade100;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.red.shade50)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  qrCode,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const DocumentDetailsModal(),
                  );
                },
                child: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: AppTheme.primaryRed,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}