import 'package:flutter/material.dart';

class IctAdminRolesScreen extends StatefulWidget {
  const IctAdminRolesScreen({Key? key}) : super(key: key);

  @override
  _IctAdminRolesScreenState createState() => _IctAdminRolesScreenState();
}

class _IctAdminRolesScreenState extends State<IctAdminRolesScreen> {
  // Theme Colors based on screenshots
  final Color bgColor = const Color(0xFFFDF7F6);
  final Color primaryRed = const Color(0xFFA81C1C);
  final Color darkCardColor = const Color(0xFF3E312F);
  final Color cardOutlineColor = const Color(0xFFE5D5D5);
  final Color lightRedBg = const Color(0xFFFCEBEB);

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
                'Operations Control Center',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: darkCardColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ICT ROOT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: cardOutlineColor, height: 1.0),
          ),
        ),
        body: Column(
          children: [
            // Static Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Permissions & Workflow Engineering',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Configure dynamic tracking routes, security matrix parameters, and registration building locations.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              labelColor: primaryRed,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: primaryRed,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('INTERACTIVE\nVISUALIZER', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.domain, size: 18),
                      SizedBox(width: 8),
                      Text('CAMPUS\nINFRASTRUCTURE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),

            // Tab Content
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

  // ==========================================
  // TAB 1: INTERACTIVE VISUALIZER
  // ==========================================
  Widget _buildInteractiveVisualizerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Compile New Workflow Card
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
                  'COMPILE NEW WORKFLOW TEMPLATE',
                  style: TextStyle(
                    color: primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Design linear multi-stop routing pipelines mapping across campus destinations.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 20),
                
                // Process Action Name Input
                Text(
                  'PROCESS ACTION NAME (E.G. EQUIPMENT BORROWING REQUEST)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter process title descriptive tag...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: cardOutlineColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: cardOutlineColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // Sequence Stops Matrix
                Text(
                  'PIPELINE TRACKING PROGRESS SEQUENCE STOPS MATRIX',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                _buildSequenceStop(1),
                const SizedBox(height: 10),
                _buildSequenceStop(2),
                const SizedBox(height: 20),

                // Action Buttons (Add / Delete)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cardOutlineColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: Text(
                          '+  Add\nDownstream\nStep',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: primaryRed, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cardOutlineColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: Text(
                          '×  Delete Last\nStep',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: primaryRed, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Deploy Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('DEPLOY TRACKING TEMPLATE', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // Pipeline Blueprints Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: darkCardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.description, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'PIPELINE BLUEPRINTS (6)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Blueprint Item 1
                _buildBlueprintItem(
                  title: 'Overtime or Extra Duty Request',
                  path: 'REGISTRATION SERVICES → OFFICE OF THE REGISTRAR → ACCOUNTING OFFICE → OFFICE OF THE CHANCELLOR → CASHIERING OFFICE',
                  isActive: false,
                ),
                const SizedBox(height: 12),
                
                // Blueprint Item 2
                _buildBlueprintItem(
                  title: 'Liquidation of Cash Advances',
                  path: 'CICS OFFICE → OFFICE OF STUDENT AFFAIRS AND SERVICES (OSAS) → REGISTRATION SERVICES → OFFICE OF THE REGISTRAR',
                  isActive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: CAMPUS INFRASTRUCTURE
  // ==========================================
  Widget _buildCampusInfrastructureTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Register Department Structure
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
                  'REGISTER NEW CAMPUS DEPARTMENT STRUCTURE',
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
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: lightRedBg,
                          border: Border.all(color: cardOutlineColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('e.g. CICS, CABEIHM', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 48,
                      width: 100,
                      decoration: BoxDecoration(
                        color: darkCardColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
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
                  'REGISTER NEW CAMPUS BRANCH OFFICE STATION NODE',
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
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: lightRedBg,
                          border: Border.all(color: cardOutlineColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('e.g. Guidance Office, Cashie', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 48,
                      width: 100,
                      decoration: BoxDecoration(
                        color: darkCardColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Text('ADD OFFICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Active Station Capacity Monitors
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
                const Text(
                  'ACTIVE STATION CAPACITY MONITORS',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  'Live index count detailing personnel distribution weights mapped straight out of storage nodes.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                
                _buildStationMonitor('Accounting Office', 2, Colors.green),
                const SizedBox(height: 10),
                _buildStationMonitor('CICS Office', 4, Colors.green),
                const SizedBox(height: 10),
                _buildStationMonitor('CE / CIT Office', 0, Colors.red),
                const SizedBox(height: 10),
                _buildStationMonitor('Campus Library', 2, Colors.green),
                const SizedBox(height: 10),
                _buildStationMonitor('Health Services', 2, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  
  Widget _buildSequenceStop(int stepNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: lightRedBg,
        border: Border.all(color: cardOutlineColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            height: 24,
            width: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF3E312F),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$stepNumber', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('-- Select Required Target', style: TextStyle(color: Colors.black87)),
          ),
          const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildBlueprintItem({required String title, required String path, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4A3A39), // Slightly lighter than the dark bg
        border: Border.all(color: isActive ? primaryRed : Colors.transparent, width: isActive ? 1.5 : 0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Icon(isActive ? Icons.edit : Icons.chevron_right, color: isActive ? primaryRed : Colors.grey[400], size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            path,
            style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.5),
          ),
          if (isActive) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('TEMPLATE ACTIVE', style: TextStyle(color: primaryRed, fontSize: 10, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: primaryRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            )
          ]
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
          Row(
            children: [
              Icon(Icons.domain, color: primaryRed, size: 16),
              const SizedBox(width: 12),
              Text(name, style: const TextStyle(color: Colors.black87, fontSize: 14)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.shade50,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              '$staffCount STAFF',
              style: TextStyle(
                color: badgeColor.shade700,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}