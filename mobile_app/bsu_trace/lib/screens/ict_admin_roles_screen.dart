import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

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
  List<Map<String, dynamic>> processBlueprints = [];

  // New Workflow State
  TextEditingController processNameController = TextEditingController();
  List<int?> selectedStops = [null, null]; // Start with 2 default stops

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch all offices for dropdowns and monitors
      final officeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/offices'));
      if (officeRes.statusCode == 200) {
        final List<dynamic> officeData = json.decode(officeRes.body);
        officesList = officeData.map((e) => e as Map<String, dynamic>).toList();
      }

      // 2. Fetch Process Types (Workflows)
      final processRes = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types'));
      if (processRes.statusCode == 200) {
        final List<dynamic> processData = json.decode(processRes.body);
        List<Map<String, dynamic>> enrichedProcesses = [];

        // Fetch route details for each process
        for (var p in processData) {
          final routeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types/${p['p_id']}/route'));
          String routeString = "Route path unassigned or empty";
          
          if (routeRes.statusCode == 200) {
            final routeData = json.decode(routeRes.body);
            List<dynamic> stops = routeData['stops'] ?? [];
            
            // Map stop IDs to Office Names
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
            'is_active': true, // Mocking active state since DB currently lacks an is_active for process
          });
        }
        processBlueprints = enrichedProcesses;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
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
          'stops': selectedStops, // List of IDs
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workflow deployed successfully!'), backgroundColor: Colors.green));
        processNameController.clear();
        setState(() => selectedStops = [null, null]);
        _fetchDashboardData(); // Refresh the list
      } else {
        throw Exception('Failed to deploy');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deployment failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: Icon(Icons.menu, color: primaryRed),
          title: Row(
            children: [
              const Text(
                'Operations Control',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: darkCardColor, borderRadius: BorderRadius.circular(4)),
                child: const Text('ICT ROOT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
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
    return SingleChildScrollView(
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
                
                // Dynamically build dropdowns based on state list
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
                        } : null, // Max 7 stops per DB schema
                        style: OutlinedButton.styleFrom(side: BorderSide(color: cardOutlineColor), padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text('+ Add Step', style: TextStyle(color: primaryRed, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: selectedStops.length > 2 ? () {
                          setState(() => selectedStops.removeLast());
                        } : null, // Min 2 stops
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
                // Render dynamically fetched processes
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
    );
  }

  Widget _buildCampusInfrastructureTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Registration Card (Static for now as there's no POST /api/offices yet)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: cardOutlineColor), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REGISTER NEW CAMPUS BRANCH OFFICE', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text('Populates available nodes inside both user assignment forms and step visuals.', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Endpoint required in server.js to add Office.')));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: darkCardColor, minimumSize: const Size(100, 48)),
                      child: const Text('ADD OFFICE', style: TextStyle(color: Colors.white, fontSize: 12)),
                    )
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: cardOutlineColor), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ACTIVE STATION CAPACITY MONITORS', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Text('Live index count detailing personnel distribution.', style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4)),
                const SizedBox(height: 20),
                
                // Dynamically display all fetched offices
                ...officesList.map((office) {
                  // Currently mocking staff count visually. server.js needs a count query attached to the office route to display real personnel counts.
                  int mockStaffCount = (office['o_id'] % 3) + 1; 
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildStationMonitor(office['office_name'], mockStaffCount, mockStaffCount > 0 ? Colors.green : Colors.red),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
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