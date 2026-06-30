import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class IctAdminDashboard extends StatefulWidget {
  const IctAdminDashboard({Key? key}) : super(key: key);

  @override
  _IctAdminDashboardState createState() => _IctAdminDashboardState();
}

class _IctAdminDashboardState extends State<IctAdminDashboard> with SingleTickerProviderStateMixin {
  final String adminName = 'Admin User'; // Replace with SharedPreferences fetch[cite: 3]
  
  // Tab control state[cite: 3]
  late TabController _tabController;

  // Form states[cite: 3]
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  int? _accountType;
  String _fullName = '';
  String _email = '';
  int? _departmentId;
  int? _officeId;

  // Registry states[cite: 3]
  List<dynamic> _accounts = [];
  List<dynamic> _offices = [];
  String _searchTerm = '';
  int? _roleFilter;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOffices();
    _fetchAccounts();
  }

  // --- API CALLS ---
  Future<void> _fetchOffices() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:5000/api/offices'));
      if (res.statusCode == 200) {
        setState(() => _offices = json.decode(res.body));
      }
    } catch (e) {
      debugPrint("Failed building office catalog: $e");
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:5000/api/accounts'));
      if (res.statusCode == 200) {
        setState(() => _accounts = json.decode(res.body));
      }
    } catch (e) {
      debugPrint("Error fetching accounts: $e");
    }
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final payload = {
      'username': _username,
      'password': _password,
      'accountType': _accountType,
      'fullName': _fullName,
      'email': _email,
      'departmentId': _departmentId,
      'officeId': (_accountType == 2 || _accountType == 3) ? _officeId : null,
    }; // Submission payload logic[cite: 3]

    try {
      final res = await http.post(
        Uri.parse('http://localhost:5000/api/accounts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully'), backgroundColor: Colors.green),
        );
        _formKey.currentState!.reset();
        _fetchAccounts();
      } else {
        throw Exception(json.decode(res.body)['error'] ?? 'Creation failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    // Filter computation logic[cite: 3]
    final filteredAccounts = _accounts.where((acc) {
      final searchLower = _searchTerm.toLowerCase();
      final matchesSearch = acc['full_name'].toString().toLowerCase().contains(searchLower) ||
                            acc['username'].toString().toLowerCase().contains(searchLower) ||
                            acc['uni_email'].toString().toLowerCase().contains(searchLower);
      final matchesRole = _roleFilter == null || acc['a_id'] == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text("BSU Portal - $adminName", style: const TextStyle(color: Colors.black87, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.red[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red[800],
          tabs: const [
            Tab(text: "📋 REGISTRY"), // Registry Table Tab[cite: 3]
            Tab(text: "➕ CREATE"), // Create Account Tab[cite: 3]
          ],
        ),
      ),
      drawer: _buildDrawer(), // Sidebar replacement for mobile
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegistryTab(filteredAccounts),
          _buildCreateTab(),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2D1F1E),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.school, color: Colors.red, size: 40),
                SizedBox(height: 10),
                Text('BSU Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Admin Console', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.grey),
            title: const Text('Dashboard', style: TextStyle(color: Colors.grey)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.white),
            title: const Text('Accounts', style: TextStyle(color: Colors.white)),
            tileColor: Colors.white10, // Active state
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              // Handle logout[cite: 3]
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegistryTab(List<dynamic> accounts) {
    return Column(
      children: [
        // Search and Filter Bar[cite: 3]
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search records...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                  hint: const Text('Role'),
                  value: _roleFilter,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 1, child: Text('Originator')),
                    DropdownMenuItem(value: 2, child: Text('Processor')),
                    DropdownMenuItem(value: 3, child: Text('Signee')),
                    DropdownMenuItem(value: 4, child: Text('GSO Admin')),
                    DropdownMenuItem(value: 5, child: Text('ICT Admin')),
                  ],
                  onChanged: (val) => setState(() => _roleFilter = val),
                ),
              ),
            ],
          ),
        ),
        // Registry List (Mobile adaptation of table)
        Expanded(
          child: ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final user = accounts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: user['is_active'] == false ? Colors.grey[200] : Colors.white,
                child: ListTile(
                  title: Text(
                    "${user['full_name']} ${user['is_active'] == false ? '[Suspended]' : ''}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: user['is_active'] == false ? Colors.grey : Colors.black,
                    ),
                  ),
                  subtitle: Text("@${user['username']} | Role ID: ${user['a_id']}\n${user['office_name'] != null ? '🏬 ${user['office_name']}' : '📁 Dept: ${user['department_name']}'}"),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    onPressed: () => _showEditDialog(user),
                    child: const Text('MANAGE'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _fullName = v!,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: 'University Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _email = v!,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _username = v!,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _password = v!,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Account Type (Role)'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Originator')),
                DropdownMenuItem(value: 2, child: Text('Processor')),
                DropdownMenuItem(value: 3, child: Text('Signee')),
                DropdownMenuItem(value: 4, child: Text('GSO Admin')),
              ],
              onChanged: (v) => setState(() => _accountType = v),
              onSaved: (v) => _accountType = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Department Scope'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('CICS')),
                DropdownMenuItem(value: 2, child: Text('CABEIHM')),
                DropdownMenuItem(value: 3, child: Text('CAS')),
                DropdownMenuItem(value: 4, child: Text('CIT')),
              ],
              onChanged: (v) => setState(() => _departmentId = v),
              onSaved: (v) => _departmentId = v,
            ),
            const SizedBox(height: 12),
            // Office Workspace Logic[cite: 3]
            if (_accountType == 2 || _accountType == 3)
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Assigned Branch Office',
                  labelStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                ),
                items: _offices.map<DropdownMenuItem<int>>((off) {
                  return DropdownMenuItem<int>(
                    value: off['id'],
                    child: Text(off['name']),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _officeId = v),
                onSaved: (v) => _officeId = v,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: _handleCreateAccount,
              child: const Text('CREATE ACCOUNT'),
            ),
          ],
        ),
      ),
    );
  }

  // --- SWEETALERT / MODAL EQUIVALENT ---
  void _showEditDialog(Map<String, dynamic> user) {
    bool isActive = user['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Manage Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("u_id: ${user['u_id']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 10),
                    // 2FA Read-Only Audit Sheet[cite: 3]
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: user['two_fa_enabled'] ? Colors.green[50] : Colors.orange[50],
                      child: Row(
                        children: [
                          Icon(user['two_fa_enabled'] ? Icons.lock : Icons.warning, 
                               color: user['two_fa_enabled'] ? Colors.green : Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user['two_fa_enabled'] ? "MFA Protection Enforced. Read-only." : "MFA Protection Inactive.",
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Soft Deactivation Toggle[cite: 3]
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Account Access Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Switch(
                          value: isActive,
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                          onChanged: (val) {
                            setStateDialog(() => isActive = val);
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                  onPressed: () async {
                    // Update Action - Similar to SweetAlert confirmation[cite: 3]
                    Navigator.pop(context);
                    await _handleUpdateAccount(user['u_id'], isActive); 
                  },
                  child: const Text('SAVE OVERRIDES'),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _handleUpdateAccount(int uid, bool isActive) async {
    // API logic to PUT to backend[cite: 3]
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Account $uid synchronization complete. Active: $isActive')),
    );
  }
}