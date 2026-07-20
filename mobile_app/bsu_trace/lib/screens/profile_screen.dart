import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
// Removed app_drawer.dart import since we are using a back button now
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
  bool _isSaving = false; 
  bool _forcePop = false; // Used to allow exiting after discarding changes
  
  Map<String, dynamic>? _userData;
  String _errorMessage = '';

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Safely parses boolean values from PostgreSQL/JSON
  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  // Helper method with STRICT type and string matching
  bool get _hasUnsavedChanges {
    if (_userData == null) return false;
    
    final originalName = (_userData!['full_name'] ?? '').toString().trim();
    final originalEmail = (_userData!['uni_email'] ?? '').toString().trim();
    final original2fa = _parseBool(_userData!['two_fa_enabled']);

    return _fullNameController.text.trim() != originalName ||
           _emailController.text.trim() != originalEmail ||
           _is2faEnabled != original2fa;
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    
    // Listen to text changes to dynamically update the PopScope
    _fullNameController.addListener(_onInputChanged);
    _emailController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _fullNameController.removeListener(_onInputChanged);
    _emailController.removeListener(_onInputChanged);
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {}); // Triggers a rebuild so PopScope knows if changes exist
  }

  // Dialog Helper to replace Snackbars
  void _showAlertDialog(String title, String message, {bool isError = true}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title, 
          style: TextStyle(
            color: isError ? Colors.red : Colors.green, 
            fontWeight: FontWeight.bold
          )
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showOTPVerificationModal() async {
    final TextEditingController pinController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verify Identity', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A verification code has been sent to your email to confirm this security change.'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8.0),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () {
              if (pinController.text.length == 6) {
                Navigator.pop(context, pinController.text);
              } else {
                _showAlertDialog('Invalid PIN', 'Please enter a 6-digit PIN.');
              }
            },
            child: const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
          _fullNameController.text = _userData?['full_name'] ?? '';
          _emailController.text = _userData?['uni_email'] ?? '';

          if (_userData != null) {
             _is2faEnabled = _parseBool(_userData!['two_fa_enabled']);
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

Future<void> _saveProfileChanges() async {
    final userId = SessionManager().userId;
    if (userId == null) return;

    final original2fa = _parseBool(_userData!['two_fa_enabled']);
    String? otpCode;

    // 1. If 2FA state changed, request an OTP from the backend
    if (_is2faEnabled != original2fa) {
      setState(() => _isSaving = true);
      try {
        final otpResponse = await http.post(
          Uri.parse('${AppConfig.baseUrl}/users/$userId/request-profile-otp'),
        );
        
        if (otpResponse.statusCode != 200) {
          setState(() => _isSaving = false);
          _showAlertDialog('Error', 'Failed to send verification email.');
          return;
        }
      } catch (e) {
        setState(() => _isSaving = false);
        _showAlertDialog('Error', 'Connection error while requesting OTP.');
        return;
      }
      setState(() => _isSaving = false);

      // 2. Show the modal to capture the user's PIN
      otpCode = await _showOTPVerificationModal();
      
      // If the user cancelled the modal or provided an invalid string, abort the save
      if (otpCode == null || otpCode.length != 6) {
        return;
      }
    }

    // 3. Proceed with the final save request
    setState(() => _isSaving = true);

    final String url = '${AppConfig.baseUrl}/users/$userId';

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': _fullNameController.text.trim(),
          'uni_email': _emailController.text.trim(),
          'two_fa_enabled': _is2faEnabled,
          if (otpCode != null) 'otp': otpCode, // Dynamically append the OTP if it exists
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _forcePop = false);
        _showAlertDialog('Success', 'Profile updated successfully!', isError: false);
        _fetchUserProfile(); 
      } else if (response.statusCode == 401) {
        _showAlertDialog('Verification Failed', 'The PIN you entered was incorrect.');
      } else {
        _showAlertDialog('Error', 'Failed to update profile.');
      }
    } catch (e) {
      _showAlertDialog('Error', 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Confirmation dialog for discarding changes
  Future<bool> _showDiscardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unsaved Changes', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
        content: const Text('You have unsaved changes. Do you want to discard them and leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Return false (stay)
            child: const Text('Stay', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () => Navigator.pop(context, true), // Return true (discard)
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // PopScope intercepts the hardware back button or AppBar back button
    return PopScope(
      canPop: !_hasUnsavedChanges || _forcePop,
      onPopInvoked: (didPop) async {
        if (didPop) return; // Pop already succeeded

        // Trigger confirmation dialog if changes exist and back is pressed
        final bool shouldPop = await _showDiscardDialog();
        if (shouldPop) {
          setState(() => _forcePop = true); // Allow the subsequent pop to pass
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(), // Replaced AppDrawer with the BackButton here
          title: const Text('My Profile'), 
          actions: buildAppBarActions(context)
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
            : _errorMessage.isNotEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center)))
                : _buildProfileContent(),
      ),
    );
  }

  Widget _buildProfileContent() {
    final String facultyId = _userData?['faculty_id'] ?? 'Not Assigned';
    final String accountType = _userData?['account_type'] ?? 'USER'; 
    final String department = _userData?['department_name'] ?? 'General Department';

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
          _buildCard(
            child: Column(
              children: [
                Container(width: 90, height: 90, decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)))),
                const SizedBox(height: 16),
                Text(currentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(20)), child: Text(accountType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Text(department, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSection(
            title: 'Personal Information',
            children: [
              _buildTextField('Full Name', _fullNameController, Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField('University Email', _emailController, Icons.mail_outline),
            ],
          ),

          _buildSection(
            title: 'Institutional Details',
            children: [
              _buildInfoCard('Faculty ID', facultyId),
              const SizedBox(height: 12),
              _buildInfoCard('Department', department),
            ],
          ),

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
                  // UPDATED: Simply toggle the state
                  setState(() {
                    _is2faEnabled = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfileChanges, 
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed, 
                padding: const EdgeInsets.symmetric(vertical: 16), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ), 
              child: _isSaving 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ),
          const SizedBox(height: 24),
          
          TextButton.icon(
            onPressed: () async { 
              // EXPLICIT LOGOUT INTERCEPTOR
              if (_hasUnsavedChanges) {
                final shouldDiscard = await _showDiscardDialog();
                if (!shouldDiscard) return; // Cancel the logout if they want to stay
              }
              
              SessionManager().logout(); 
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false); 
              }
            }, 
            icon: const Icon(Icons.logout, color: AppTheme.primaryRed), 
            label: const Text('LOGOUT', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) => Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)), child: child);
  Widget _buildSection({required String title, required List<Widget> children}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16), _buildCard(child: Column(children: children)), const SizedBox(height: 20)]);
  Widget _buildTextField(String label, TextEditingController controller, IconData icon) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)), const SizedBox(height: 8), TextFormField(controller: controller, decoration: InputDecoration(suffixIcon: Icon(icon, color: Colors.black54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))]);
  Widget _buildInfoCard(String title, String value) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]));
  Widget _buildSecurityTile(String title, IconData icon, {VoidCallback? onTap}) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: AppTheme.primaryRed), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.chevron_right), onTap: onTap);
}