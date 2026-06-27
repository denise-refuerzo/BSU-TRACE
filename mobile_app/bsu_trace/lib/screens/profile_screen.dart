import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../services/session_manager.dart';
import '../config.dart';
import '../widgets/modals/change_password_modal.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _is2faEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false; // Tracks if the save request is running
  
  Map<String, dynamic>? _userData;
  String _errorMessage = '';

  // Controllers to capture edited text
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    final userId = SessionManager().userId;
    if (userId == null) {
      setState(() {
        _errorMessage = "No active session found. Please log in again.";
        _isLoading = false;
      });
      return;
    }

    final String url = '${AppConfig.baseUrl}/users/$userId';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _userData = json.decode(response.body);
          
          // Populate the text controllers with the fetched data
          _fullNameController.text = _userData?['full_name'] ?? '';
          _emailController.text = _userData?['uni_email'] ?? '';

          if (_userData != null && _userData!['two_fa_enabled'] != null) {
             _is2faEnabled = _userData!['two_fa_enabled'];
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load profile data (Status: ${response.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not connect to server.';
        _isLoading = false;
      });
    }
  }

  // --- NEW: Save Function ---
  Future<void> _saveProfileChanges() async {
    final userId = SessionManager().userId;
    if (userId == null) return;

    setState(() => _isSaving = true);

    final String url = '${AppConfig.baseUrl}/users/$userId';

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': _fullNameController.text.trim(),
          'uni_email': _emailController.text.trim(),
          'two_fa_enabled': _is2faEnabled, // Saves the toggle switch state too!
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
        // Refresh the profile to update the header Avatar and Name
        _fetchUserProfile(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error. Please try again.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), actions: buildAppBarActions(context)),
      drawer: const AppDrawer(),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                )
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    final String facultyId = _userData?['faculty_id'] ?? 'Not Assigned';
    final String accountType = _userData?['account_type'] ?? 'USER'; 
    final String department = _userData?['department_name'] ?? 'General Department';

    // We generate initials based on the currently typed name in the controller, 
    // or fallback to the fetched data
    String currentName = _fullNameController.text.isNotEmpty ? _fullNameController.text : (_userData?['full_name'] ?? 'U');
    String initials = "U";
    if (currentName.trim().isNotEmpty) {
      List<String> nameParts = currentName.trim().split(' ');
      if (nameParts.length > 1) {
        initials = '${nameParts[0][0]}${nameParts[nameParts.length - 1][0]}'.toUpperCase();
      } else {
        initials = nameParts[0][0].toUpperCase();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // --- HEADER SECTION ---
          _buildCard(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 90, 
                      height: 90, 
                      decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), 
                      child: Center(
                        child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryRed))
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(currentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(20)),
                  child: Text(accountType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Text(department, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- PERSONAL INFO SECTION ---
          _buildSection(
            title: 'Personal Information',
            children: [
              _buildTextField('Full Name', _fullNameController, Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField('University Email', _emailController, Icons.mail_outline),
            ],
          ),

          // --- INSTITUTIONAL DETAILS SECTION ---
          _buildSection(
            title: 'Institutional Details',
            children: [
              _buildInfoCard('Faculty ID', facultyId),
              const SizedBox(height: 12),
              _buildInfoCard('Department', department),
              const SizedBox(height: 16),
              const Text(
                'Please contact the ICT Office to update institutional information.', 
                style: TextStyle(color: Colors.black54, fontSize: 12, fontStyle: FontStyle.italic)
              ),
            ],
          ),

          // --- SECURITY SECTION ---
          _buildSection(
            title: 'Account Security',
            children: [
              _buildSecurityTile('Change Password', Icons.lock_outline, onTap: () {
                showDialog(context: context, builder: (context) => const ChangePasswordModal());
              }),
              const Divider(),
              SwitchListTile(
                title: const Text('Two-Factor Authentication', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Enhanced protection for your portal access', style: TextStyle(fontSize: 12)),
                value: _is2faEnabled,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: (val) {
                  setState(() => _is2faEnabled = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- ACTIONS ---
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfileChanges, // Triggers Save
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed, 
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ), 
                  child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _fetchUserProfile(), // Cancel resets the data to original state
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppTheme.primaryRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                  child: const Text('CANCEL', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
                )
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () {
               SessionManager().logout();
               Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            }, 
            icon: const Icon(Icons.logout, color: AppTheme.primaryRed), 
            label: const Text('LOGOUT', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- REUSABLE WIDGETS ---
  Widget _buildCard({required Widget child}) => Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)), child: child);
  
  Widget _buildSection({required String title, required List<Widget> children}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _buildCard(child: Column(children: children)),
      const SizedBox(height: 20),
    ],
  );
  
  // Updated to use TextEditingController instead of hardcoded initial value
  Widget _buildTextField(String label, TextEditingController controller, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, 
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)), 
      const SizedBox(height: 8), 
      TextFormField(
        controller: controller, 
        decoration: InputDecoration(
          suffixIcon: Icon(icon, color: Colors.black54), 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
        )
      )
    ]
  );
  
  Widget _buildInfoCard(String title, String value) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]));
  
  Widget _buildSecurityTile(String title, IconData icon, {VoidCallback? onTap}) => ListTile(
    contentPadding: EdgeInsets.zero, 
    leading: Icon(icon, color: AppTheme.primaryRed), 
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), 
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}