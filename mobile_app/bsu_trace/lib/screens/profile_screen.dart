// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../services/session_manager.dart';
import '../config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _is2faEnabled = false;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
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

      // Helpful debugging logs
      debugPrint('--- PROFILE FETCH DEBUG ---');
      debugPrint('Attempting to fetch: $url');
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('---------------------------');

      if (response.statusCode == 200) {
        setState(() {
          _userData = json.decode(response.body);
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
      debugPrint('Profile Fetch Error: $e');
      setState(() {
        _errorMessage = 'Could not connect to server.';
        _isLoading = false;
      });
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
    // Safely extract data with fallbacks
    final String fullName = _userData?['full_name'] ?? 'Unknown User';
    final String email = _userData?['uni_email'] ?? 'No Email Provided';
    final String facultyId = _userData?['faculty_id'] ?? 'Not Assigned';
    final String accountType = _userData?['account_type'] ?? 'USER'; 
    final String department = _userData?['department_name'] ?? 'General Department';

    // Generate initials for the avatar (e.g., "John Doe" -> "JD")
    String initials = "U";
    if (fullName.trim().isNotEmpty) {
      List<String> nameParts = fullName.trim().split(' ');
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
                      decoration: BoxDecoration(color: AppTheme.primaryRed.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), 
                      child: Center(
                        child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryRed))
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6), 
                      decoration: BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), 
                      child: const Icon(Icons.edit, color: Colors.white, size: 14)
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(20)),
                  child: Text(accountType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Text(department, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)), 
                  child: const Text('Active Status', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12))
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- PERSONAL INFO SECTION ---
          _buildSection(
            title: 'Personal Information',
            actionText: 'Edit All',
            children: [
              _buildTextField('Full Name', fullName, Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField('University Email', email, Icons.mail_outline),
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
              _buildSecurityTile('Change Password', Icons.history),
              const Divider(),
              SwitchListTile(
                title: const Text('Two-Factor Authentication', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Enhanced protection for your portal access', style: TextStyle(fontSize: 12)),
                value: _is2faEnabled,
                activeColor: AppTheme.primaryRed,
                onChanged: (val) {
                  setState(() => _is2faEnabled = val);
                  // Optionally add backend call here to update 2FA status
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
                  onPressed: () {}, 
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                  child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {}, 
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
  
  Widget _buildSection({required String title, String? actionText, required List<Widget> children}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if(actionText != null) Text(actionText, style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12))]),
      const SizedBox(height: 16),
      _buildCard(child: Column(children: children)),
      const SizedBox(height: 20),
    ],
  );
  
  Widget _buildTextField(String label, String value, IconData icon) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)), const SizedBox(height: 8), TextFormField(initialValue: value, decoration: InputDecoration(suffixIcon: Icon(icon, color: Colors.black54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))]);
  
  Widget _buildInfoCard(String title, String value) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]));
  
  Widget _buildSecurityTile(String title, IconData icon) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: AppTheme.primaryRed), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.chevron_right));
}