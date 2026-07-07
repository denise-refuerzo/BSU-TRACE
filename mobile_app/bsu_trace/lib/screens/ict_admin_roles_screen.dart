import 'dart:async'; // Added for Timer
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_helper.dart';

class IctAdminRolesScreen extends StatefulWidget {
  const IctAdminRolesScreen({Key? key}) : super(key: key);

  @override
  _IctAdminRolesScreenState createState() => _IctAdminRolesScreenState();
}

class _IctAdminRolesScreenState extends State<IctAdminRolesScreen> {
  // Theme Colors
  final Color bgColor = const Color(0xFFFDF7F6);
  final Color primaryRed = const Color(0xFFA81C1C);
  final Color darkCardColor = const Color(0xFF3E312F);
  final Color cardOutlineColor = const Color(0xFFE5D5D5);
  final Color lightRedBg = const Color(0xFFFCEBEB);

  // State Variables
  bool isLoading = true;
  List<Map<String, dynamic>> officesList = [];
  List<Map<String, dynamic>> departmentsList = [];
  List<Map<String, dynamic>> processBlueprints = [];
  
  bool showOffices = true;

  // Controllers
  TextEditingController processNameController = TextEditingController();
  TextEditingController departmentController = TextEditingController();
  TextEditingController officeController = TextEditingController();
  
  List<int?> selectedStops = [null, null];

  // Auto-reload timer
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    
    // Auto-reload data in the background every 30 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchDashboardData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel(); // Cancel timer to prevent memory leaks
    processNameController.dispose();
    departmentController.dispose();
    officeController.dispose();
    super.dispose();
  }

  // Added isBackground flag to prevent full-screen spinner flicker during auto-reloads
  Future<void> _fetchDashboardData({bool isBackground = false}) async {
    if (!isBackground && mounted) {
      setState(() => isLoading = true);
    }
    try {
      // 1. Fetch Offices
      final officeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/offices'));
      if (officeRes.statusCode == 200) {
        final List<dynamic> officeData = json.decode(officeRes.body);
        officesList = officeData.map((e) => e as Map<String, dynamic>).toList();
      }

      // 2. Fetch Departments
      final deptRes = await http.get(Uri.parse('${AppConfig.baseUrl}/departments'));
      if (deptRes.statusCode == 200) {
        final List<dynamic> deptData = json.decode(deptRes.body);
        departmentsList = deptData.map((e) => e as Map<String, dynamic>).toList();
      }

      // 3. Fetch Process Types (Workflows)
      final processRes = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types'));
      if (processRes.statusCode == 200) {
        final List<dynamic> processData = json.decode(processRes.body);
        List<Map<String, dynamic>> enrichedProcesses = [];

        for (var p in processData) {
          final routeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types/${p['p_id']}/route'));
          String routeString = "Route path unassigned or empty";
          
          if (routeRes.statusCode == 200) {
            final routeData = json.decode(routeRes.body);
            List<dynamic> stops = routeData['stops'] ?? [];
            
            List<String> stopNames = [];
            for (var stopId in stops) {
              final office = officesList.firstWhere(
                (o) => o['o_id'] == stopId, 
                orElse: () => {'office_name': 'Unknown Node'}
              );
              stopNames.add(office['office_name']);
            }
            if (stopNames.isNotEmpty) routeString = stopNames.join(' → ');
          }

          enrichedProcesses.add({
            'p_id': p['p_id'],
            'process_name': p['process_name'],
            'path': routeString,
            'is_active': true, 
          });
        }
        processBlueprints = enrichedProcesses;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deployNewTemplate() async {
    if (processNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a process name')));
      return;
    }
    if (selectedStops.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an office for all stops')));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/process-types'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'process_name': processNameController.text.trim(),
          'stops': selectedStops, 
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workflow deployed successfully!'), backgroundColor: Colors.green));
        processNameController.clear();
        setState(() => selectedStops = [null, null]);
        _fetchDashboardData(isBackground: true); 
      } else {
        throw Exception('Failed to deploy');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deployment failed: $e')));
    }
  }

  Future<void> _addDepartment() async {
    if (departmentController.text.trim().isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/departments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'department_name': departmentController.text.trim()}),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department added successfully!'), backgroundColor: Colors.green));
        departmentController.clear();
        _fetchDashboardData(isBackground: true); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add department'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addOffice() async {
    if (officeController.text.trim().isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/offices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'office_name': officeController.text.trim()}),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Office added successfully!'), backgroundColor: Colors.green));
        officeController.clear();
        _fetchDashboardData(isBackground: true); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add office'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          toolbarHeight: 80,
          title: const Text(
            'Roles & Matrix',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: buildAppBarActions(context),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: cardOutlineColor, height: 1.0),
          ),
        ),
        body: isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryRed))
          : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Permissions & Workflow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2)),
                  const SizedBox(height: 10),
                  Text('Configure dynamic tracking routes, security matrix parameters, and locations.', style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4)),
                ],
              ),
            ),
            TabBar(
              labelColor: primaryRed,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: primaryRed,
              indicatorWeight: 3,
              tabs: const [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map_outlined, size: 18), SizedBox(width: 8), Text('VISUALIZER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.domain, size: 18), SizedBox(width: 8), Text('INFRASTRUCTURE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))])),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildInteractiveVisualizerTab(),
                  _buildCampusInfrastructureTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveVisualizerTab() {
    // Wrapped with RefreshIndicator
    return RefreshIndicator(
      color: primaryRed,
      onRefresh: () => _fetchDashboardData(isBackground: true),
      child: SingleChildScrollView(
        // AlwaysScrollableScrollPhysics ensures pull-to-refresh works even if content isn't tall enough to scroll natively
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: cardOutlineColor), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COMPILE NEW WORKFLOW TEMPLATE', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Design linear multi-stop routing pipelines mapping across campus destinations.', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  const SizedBox(height: 20),
                  Text('PROCESS ACTION NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  TextField(
                    controller: processNameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Equipment Borrowing Request',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(borderSide: BorderSide(color: cardOutlineColor), borderRadius: BorderRadius.circular(4)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cardOutlineColor)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('PIPELINE TRACKING SEQUENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  
                  ...List.generate(selectedStops.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildSequenceStop(index),
                    );
                  }),
                  
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: selectedStops.length < 7 ? () {
                            setState(() => selectedStops.add(null));
                          } : null, 
                          style: OutlinedButton.styleFrom(side: BorderSide(color: cardOutlineColor), padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: Text('+ Add Step', style: TextStyle(color: primaryRed, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: selectedStops.length > 2 ? () {
                            setState(() => selectedStops.removeLast());
                          } : null, 
                          style: OutlinedButton.styleFrom(side: BorderSide(color: cardOutlineColor), padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: Text('× Delete Last', style: TextStyle(color: primaryRed, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _deployNewTemplate,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryRed, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('DEPLOY TRACKING TEMPLATE', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: darkCardColor, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('PIPELINE BLUEPRINTS (${processBlueprints.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...processBlueprints.map((process) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildBlueprintItem(
                        title: process['process_name'],
                        path: process['path'],
                        isActive: process['is_active'],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampusInfrastructureTab() {
    // Wrapped with RefreshIndicator
    return RefreshIndicator(
      color: primaryRed,
      onRefresh: () => _fetchDashboardData(isBackground: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Register New Department Structure
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: cardOutlineColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REGISTER NEW CAMPUS DEPARTMENT',
                    style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Expands available lookups inside user account creation forms option blocks.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: departmentController,
                          decoration: InputDecoration(
                            hintText: 'e.g. CICS, CABEIHM',
                            filled: true,
                            fillColor: lightRedBg,
                            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addDepartment,
                        style: ElevatedButton.styleFrom(backgroundColor: darkCardColor, minimumSize: const Size(100, 48)),
                        child: const Text('ADD DEPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Register Branch Office
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: cardOutlineColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REGISTER NEW CAMPUS BRANCH OFFICE NODE',
                    style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Populates available nodes inside both user assignment forms and step visuals.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: officeController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Guidance Office',
                            filled: true,
                            fillColor: lightRedBg,
                            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addOffice,
                        style: ElevatedButton.styleFrom(backgroundColor: darkCardColor, minimumSize: const Size(100, 48)),
                        child: const Text('ADD OFFICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // List View with Segmented Toggle Control Below Title
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: darkCardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    children: [
                      Icon(showOffices ? Icons.hub : Icons.business, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('ACTIVE INFRASTRUCTURE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // The Toggle Switches
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => showOffices = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: showOffices ? primaryRed : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('OFFICES', style: TextStyle(color: showOffices ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => showOffices = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: !showOffices ? primaryRed : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('DEPARTMENTS', style: TextStyle(color: !showOffices ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Conditionally render based on the toggle
                  if (showOffices) ...[
                    if (officesList.isEmpty)
                      const Text('No offices registered yet.', style: TextStyle(color: Colors.white54, fontSize: 12))
                    else
                      ...officesList.map((office) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildStationMonitor(
                            office['office_name'] ?? 'Unknown Node', 
                            office['staff_count'] ?? 0,
                            Colors.grey
                          ),
                        );
                      }).toList(),
                  ] else ...[
                    if (departmentsList.isEmpty)
                      const Text('No departments registered yet.', style: TextStyle(color: Colors.white54, fontSize: 12))
                    else
                      ...departmentsList.map((dept) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildStationMonitor(
                            dept['department_name'] ?? 'Unknown Dept', 
                            dept['staff_count'] ?? 0,
                            Colors.blueGrey
                          ),
                        );
                      }).toList(),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSequenceStop(int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: lightRedBg,
        border: Border.all(color: cardOutlineColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            height: 24, width: 24,
            decoration: const BoxDecoration(color: Color(0xFF3E312F), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                hint: const Text('Select Required Target', style: TextStyle(color: Colors.black54, fontSize: 13)),
                value: selectedStops[index],
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                items: officesList.map((office) {
                  return DropdownMenuItem<int>(
                    value: office['o_id'],
                    child: Text(office['office_name'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => selectedStops[index] = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlueprintItem({required String title, required String path, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4A3A39),
        border: Border.all(color: isActive ? primaryRed : Colors.transparent, width: isActive ? 1.5 : 0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
              Icon(isActive ? Icons.edit : Icons.chevron_right, color: isActive ? primaryRed : Colors.grey[400], size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(path, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStationMonitor(String name, int staffCount, MaterialColor badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cardOutlineColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.domain, color: primaryRed, size: 16),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: const TextStyle(color: Colors.black87, fontSize: 14), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: badgeColor.shade50, borderRadius: BorderRadius.circular(2)),
            child: Text('$staffCount STAFF', style: TextStyle(color: badgeColor.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}