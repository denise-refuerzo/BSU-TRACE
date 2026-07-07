import 'dart:async';
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

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchDashboardData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    processNameController.dispose();
    departmentController.dispose();
    officeController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData({bool isBackground = false}) async {
    if (!isBackground && mounted) setState(() => isLoading = true);
    
    try {
      final officeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/offices'));
      if (officeRes.statusCode == 200) {
        final List<dynamic> officeData = json.decode(officeRes.body);
        officesList = officeData.map((e) => e as Map<String, dynamic>).toList();
      }

      final deptRes = await http.get(Uri.parse('${AppConfig.baseUrl}/departments'));
      if (deptRes.statusCode == 200) {
        final List<dynamic> deptData = json.decode(deptRes.body);
        departmentsList = deptData.map((e) => e as Map<String, dynamic>).toList();
      }

      final processRes = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types'));
      if (processRes.statusCode == 200) {
        final List<dynamic> processData = json.decode(processRes.body);
        List<Map<String, dynamic>> enrichedProcesses = [];

        for (var p in processData) {
          final routeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types/${p['p_id']}/route'));
          String routeString = "Route path unassigned or empty";
          List<dynamic> rawStops = [];
          
          if (routeRes.statusCode == 200) {
            final routeData = json.decode(routeRes.body);
            rawStops = routeData['stops'] ?? [];
            
            List<String> stopNames = [];
            for (var stopId in rawStops) {
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
            'raw_stops': rawStops, // Keep raw IDs for editing
            'is_active': true, 
          });
        }
        processBlueprints = enrichedProcesses;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- CRUD HELPERS ---

  Future<void> _updateItem(String endpoint, int id, String fieldKey, String newValue) async {
    if (newValue.trim().isEmpty) return;
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/$endpoint/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({fieldKey: newValue.trim()}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!'), backgroundColor: Colors.green));
        _fetchDashboardData(isBackground: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update item'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteItem(String endpoint, int id) async {
    try {
      final response = await http.delete(Uri.parse('${AppConfig.baseUrl}/$endpoint/$id'));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully!'), backgroundColor: Colors.green));
        _fetchDashboardData(isBackground: true);
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorData['error'] ?? 'Failed to delete'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showEditNameDialog(String title, String initialValue, Function(String) onSave) {
    TextEditingController editController = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $title', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: editController,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryRed)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(editController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: darkCardColor),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(String itemName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text('Are you sure you want to delete "$itemName"?\n\nIf this item is currently bound to active users or documents, the system will reject the deletion to protect tracking integrity.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                onConfirm();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- ROUTE EDITOR MODAL ---
  void _showEditRouteDialog(int processId, String processName, List<dynamic> rawStops) {
    // Convert dynamic list to List<int?>
    List<int?> editingStops = rawStops.map((s) => s as int?).toList();
    if (editingStops.length < 2) {
      editingStops = [null, null]; // Safety fallback
    }

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder so the modal can rebuild its own internal dropdowns
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(20),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Route Sequence', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(processName, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(editingStops.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: lightRedBg,
                              border: Border.all(color: cardOutlineColor),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 20, width: 20,
                                  decoration: const BoxDecoration(color: Color(0xFF3E312F), shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      hint: const Text('Select Office', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                      value: editingStops[index],
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                      items: officesList.map((office) {
                                        return DropdownMenuItem<int>(
                                          value: office['o_id'],
                                          child: Text(office['office_name'], style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setStateModal(() => editingStops[index] = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: editingStops.length < 7 ? () {
                                setStateModal(() => editingStops.add(null));
                              } : null, 
                              style: OutlinedButton.styleFrom(side: BorderSide(color: cardOutlineColor), padding: const EdgeInsets.symmetric(vertical: 8)),
                              child: Text('+ Add Step', style: TextStyle(color: primaryRed, fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: editingStops.length > 2 ? () {
                                setStateModal(() => editingStops.removeLast());
                              } : null, 
                              style: OutlinedButton.styleFrom(side: BorderSide(color: cardOutlineColor), padding: const EdgeInsets.symmetric(vertical: 8)),
                              child: Text('× Delete Last', style: TextStyle(color: primaryRed, fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (editingStops.contains(null)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an office for all stops')));
                      return;
                    }
                    Navigator.pop(context); // Close modal
                    
                    try {
                      final response = await http.put(
                        Uri.parse('${AppConfig.baseUrl}/process-types/$processId/route'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({'stops': editingStops}),
                      );
                      if (response.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route updated successfully!'), backgroundColor: Colors.green));
                        _fetchDashboardData(isBackground: true); 
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update route'), backgroundColor: Colors.red));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: darkCardColor),
                  child: const Text('Save Route', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // --- EXISTING ACTIONS ---

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
    return RefreshIndicator(
      color: primaryRed,
      onRefresh: () => _fetchDashboardData(isBackground: true),
      child: SingleChildScrollView(
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
                        id: process['p_id'],
                        title: process['process_name'],
                        path: process['path'],
                        isActive: process['is_active'],
                        onEditName: () {
                          _showEditNameDialog('Workflow Name', process['process_name'], (newName) {
                            _updateItem('process-types', process['p_id'], 'process_name', newName);
                          });
                        },
                        onEditRoute: () {
                          // Opens the route sequence editor modal
                          _showEditRouteDialog(process['p_id'], process['process_name'], process['raw_stops']);
                        },
                        onDelete: () {
                          _showDeleteConfirmation(process['process_name'], () {
                            _deleteItem('process-types', process['p_id']);
                          });
                        },
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
                  Row(
                    children: [
                      Icon(showOffices ? Icons.hub : Icons.business, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('ACTIVE INFRASTRUCTURE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
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
                  
                  if (showOffices) ...[
                    if (officesList.isEmpty)
                      const Text('No offices registered yet.', style: TextStyle(color: Colors.white54, fontSize: 12))
                    else
                      ...officesList.map((office) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildStationMonitor(
                            name: office['office_name'] ?? 'Unknown Node', 
                            staffCount: office['staff_count'] ?? 0,
                            badgeColor: Colors.grey,
                            onEdit: () {
                              _showEditNameDialog('Office Name', office['office_name'], (newName) {
                                _updateItem('offices', office['o_id'], 'office_name', newName);
                              });
                            },
                            onDelete: () {
                              _showDeleteConfirmation(office['office_name'], () {
                                _deleteItem('offices', office['o_id']);
                              });
                            }
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
                            name: dept['department_name'] ?? 'Unknown Dept', 
                            staffCount: dept['staff_count'] ?? 0,
                            badgeColor: Colors.blueGrey,
                            onEdit: () {
                              _showEditNameDialog('Department Name', dept['department_name'], (newName) {
                                _updateItem('departments', dept['d_id'], 'department_name', newName);
                              });
                            },
                            onDelete: () {
                              _showDeleteConfirmation(dept['department_name'], () {
                                _deleteItem('departments', dept['d_id']);
                              });
                            }
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

  Widget _buildBlueprintItem({
    required int id,
    required String title, 
    required String path, 
    required bool isActive,
    required VoidCallback onEditName,
    required VoidCallback onEditRoute,
    required VoidCallback onDelete,
  }) {
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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white70),
                    tooltip: 'Edit Process Name',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onEditName,
                  ),
                  IconButton(
                    icon: const Icon(Icons.alt_route, size: 16, color: Colors.white70),
                    tooltip: 'Edit Route Sequence',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onEditRoute,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    tooltip: 'Delete Workflow',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: onDelete,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(path, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStationMonitor({
    required String name, 
    required int staffCount, 
    required MaterialColor badgeColor,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: badgeColor.shade50, borderRadius: BorderRadius.circular(2)),
            child: Text('$staffCount STAFF', style: TextStyle(color: badgeColor.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.black54),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: onDelete,
              ),
            ],
          )
        ],
      ),
    );
  }
}