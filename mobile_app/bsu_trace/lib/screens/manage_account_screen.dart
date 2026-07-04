import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../theme/app_theme.dart';
import '../../../config.dart';

class ManageAccountScreen extends StatefulWidget {
  final dynamic user;

  const ManageAccountScreen({super.key, required this.user});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Text Controllers for Editable Details
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  // Dropdown States
  late int _selectedRoleId;
  late int _selectedDeptId;
  
  // Toggle States
  late bool _isActive;
  late bool _is2FAEnabled;
  String? _new2FAPin; // Stores the PIN if the admin just enabled it

  // --- INITIAL STATE TRACKERS (For the Unsaved Changes Check) ---
  late String _initialName;
  late String _initialEmail;
  late int _initialRoleId;
  late int _initialDeptId;
  late bool _initialActive;
  late bool _initial2FA;

  final Map<String, int> _roles = {
    'Originator': 1, 'Processor': 2, 'Signee': 3, 'GSO Admin': 4, 'ICT Admin': 5
  };
  final Map<String, int> _departments = {
    'CICS': 1, 'CABEIHM': 2, 'CAS': 3, 'CIT': 4
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['full_name'] ?? '');
    _emailController = TextEditingController(text: widget.user['uni_email'] ?? '');
    _isActive = widget.user['is_active'] ?? true;
    _is2FAEnabled = widget.user['two_fa_enabled'] ?? false;
    
    String currentRole = widget.user['role'] ?? 'Originator';
    _selectedRoleId = _roles[currentRole] ?? 1;

    String currentDept = widget.user['department'] ?? 'CICS';
    _selectedDeptId = _departments[currentDept] ?? 1;

    // Snapshot the initial state so we can compare it later
    _initialName = _nameController.text;
    _initialEmail = _emailController.text;
    _initialRoleId = _selectedRoleId;
    _initialDeptId = _selectedDeptId;
    _initialActive = _isActive;
    _initial2FA = _is2FAEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ==========================================
  // UNSAVED CHANGES LOGIC
  // ==========================================

  bool get _hasUnsavedChanges {
    return _nameController.text != _initialName ||
           _emailController.text != _initialEmail ||
           _selectedRoleId != _initialRoleId ||
           _selectedDeptId != _initialDeptId ||
           _isActive != _initialActive ||
           _is2FAEnabled != _initial2FA ||
           _new2FAPin != null;
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true; // Safe to pop if no changes

    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unsaved Changes', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
        content: const Text('You have unsaved changes. Are you sure you want to discard them and leave this page?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return discard ?? false;
  }

  // ==========================================
  // MODALS & DIALOGS
  // ==========================================

  Future<void> _handle2FAToggle(bool newValue) async {
    if (newValue) {
      final String? pin = await _showSetup2FAModal();
      if (pin != null && pin.length >= 4) {
        setState(() {
          _is2FAEnabled = true;
          _new2FAPin = pin;
        });
      }
    } else {
      final bool? confirm = await _showDisable2FAModal();
      if (confirm == true) {
        setState(() {
          _is2FAEnabled = false;
          _new2FAPin = null;
        });
      }
    }
  }

  Future<String?> _showSetup2FAModal() {
    final TextEditingController pinController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Setup 2FA PIN', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a secure 6-digit PIN for this user.'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'e.g., 123456',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () => Navigator.pop(context, pinController.text),
            child: const Text('Enable 2FA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDisable2FAModal() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disable 2FA?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to turn off Two-Factor Authentication for this user? They will no longer need a PIN to log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Turn Off', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete this user account? This action cannot be undone and will remove their access entirely.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final response = await http.delete(Uri.parse('${AppConfig.baseUrl}/users/${widget.user['u_id']}'));
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted successfully'), backgroundColor: Colors.green));
          Navigator.pop(context, true); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete account'), backgroundColor: Colors.red));
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.'), backgroundColor: Colors.red));
      }
    }
  }

  // ==========================================
  // API CALLS
  // ==========================================

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/users/${widget.user['u_id']}/admin-update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': _nameController.text,
          'uni_email': _emailController.text,
          'a_id': _selectedRoleId,
          'd_id': _selectedDeptId,
          'is_active': _isActive,
          'two_fa_enabled': _is2FAEnabled,
          'two_fa_code': _new2FAPin, 
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        // Update initials to indicate we are successfully saved (no unsaved changes warning needed)
        _initialName = _nameController.text;
        _initialEmail = _emailController.text;
        _initialRoleId = _selectedRoleId;
        _initialDeptId = _selectedDeptId;
        _initialActive = _isActive;
        _initial2FA = _is2FAEnabled;
        _new2FAPin = null;

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account updated successfully'), backgroundColor: Colors.green));
        Navigator.pop(context, true); 
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Failed to update account';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final String initial = _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?';

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final bool shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Account'), 
          leading: IconButton(
            icon: const Icon(Icons.arrow_back), 
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.pop(context);
              }
            }
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.red.shade50,
                    child: Text(initial, style: const TextStyle(fontSize: 32, color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),
                
                const Text('Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTextField('Full Name', _nameController, Icons.person_outline),
                _buildTextField('University Email', _emailController, Icons.email_outlined, isEmail: true),

                const SizedBox(height: 16),
                const Text('Organizational Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildDropdown('System Role', _roles, _selectedRoleId, (val) => setState(() => _selectedRoleId = val!)),
                _buildDropdown('Department', _departments, _selectedDeptId, (val) => setState(() => _selectedDeptId = val!)),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                const Text('Security & Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Active Account Toggle
                _buildToggleItem(
                  title: 'Active Account',
                  subtitle: _isActive ? 'User is allowed to log in' : 'User is restricted from logging in',
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                
                // 2FA Toggle 
                _buildToggleItem(
                  title: 'Two-Factor Authentication',
                  subtitle: 'Require PIN verification on login',
                  value: _is2FAEnabled,
                  onChanged: _handle2FAToggle, 
                ),

                const SizedBox(height: 24),

                // MOVED: Save Changes Button directly under the security toggles
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // Delete Button (Danger Zone at the bottom)
                _buildActionCard(
                  title: 'Delete Account',
                  subtitle: 'Permanently remove this user from the system',
                  icon: Icons.delete_outline,
                  iconColor: AppTheme.primaryRed,
                  iconBgColor: Colors.red.shade50,
                  isDestructive: true,
                  onTap: _handleDeleteAccount, 
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
            validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
            decoration: InputDecoration(prefixIcon: Icon(icon, color: Colors.grey, size: 20), filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300))),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, Map<String, int> items, int currentValue, void Function(int?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(value: currentValue, isExpanded: true, icon: const Icon(Icons.expand_more, color: Colors.grey), onChanged: onChanged, items: items.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontSize: 15)))).toList()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({required String title, required String subtitle, required bool value, required void Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primaryRed, activeTrackColor: Colors.red.shade100),
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color iconColor, required Color iconBgColor, required VoidCallback onTap, bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: isDestructive ? Colors.red.shade200 : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDestructive ? AppTheme.primaryRed : Colors.black87)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
          ],
        ),
      ),
    );
  }
}