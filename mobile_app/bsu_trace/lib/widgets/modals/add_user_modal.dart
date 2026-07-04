import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../config.dart';

class AddUserModal extends StatefulWidget {
  const AddUserModal({super.key});

  @override
  State<AddUserModal> createState() => _AddUserModalState();
}

class _AddUserModalState extends State<AddUserModal> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Dropdown States
  int _selectedRoleId = 1; 
  int? _selectedDeptId;    
  int? _selectedOfficeId;  

  final Map<String, int> _roles = {
    'Originator': 1, 'Processor': 2, 'Signee': 3, 
    'GSO Admin': 4, 'ICT Admin': 5
  };

  final Map<String, int> _departments = {
    'CICS': 1, 'CABEIHM': 2, 'CAS': 3, 'CIT': 4
  };

  final Map<String, int> _offices = {
    'Dean\'s Office': 1, 'Registrar': 2, 'Accounting': 3, 'GSO': 4
  };

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Conditional Validation: Department is ONLY required for Originator (1)
    if (_selectedRoleId == 1 && _selectedDeptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department is required for Originators'), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Conditional Validation: Office is REQUIRED for Processors (2) and Signees (3)
    if ([2, 3].contains(_selectedRoleId) && _selectedOfficeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Office is required for Processors and Signees'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': _fullNameController.text,
          'uni_email': _emailController.text,
          'username': _usernameController.text,
          'password': _passwordController.text,
          'a_id': _selectedRoleId,
          'd_id': _selectedDeptId, 
          'o_id': [2, 3].contains(_selectedRoleId) ? _selectedOfficeId : null,
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); 
      } else {
        final error = json.decode(response.body)['error'] ?? 'Failed to create user';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    // UPDATED: Department is now ONLY required for Originators (1)
    bool isDeptRequired = _selectedRoleId == 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
        padding: const EdgeInsets.all(32), 
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add New User', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                
                _buildTextField('Full Name', _fullNameController, Icons.person_outline),
                _buildTextField('University Email', _emailController, Icons.email_outlined, isEmail: true),
                _buildTextField('Username', _usernameController, Icons.badge_outlined),
                _buildPasswordField(),
                
                // System Role Dropdown
                _buildDropdown('System Role', _roles, _selectedRoleId, (val) {
                  setState(() {
                    _selectedRoleId = val!;
                    // If switching away from Processor/Signee, clear the office selection
                    if (![2, 3].contains(_selectedRoleId)) {
                      _selectedOfficeId = null;
                    }
                  });
                }, isRequired: true),

                // Department Dropdown (Dynamically Required/Optional)
                _buildDropdown(
                  'Department', 
                  _departments, 
                  _selectedDeptId, 
                  (val) => setState(() => _selectedDeptId = val), 
                  isOptional: !isDeptRequired, 
                  isRequired: isDeptRequired
                ),
                
                // Office Dropdown (Only visible for Processors and Signees)
                if ([2, 3].contains(_selectedRoleId))
                  _buildDropdown('Assigned Office', _offices, _selectedOfficeId, (val) => setState(() => _selectedOfficeId = val), isRequired: true),

                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  height: 52, 
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create User Account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              const Text(' *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required field';
              if (isEmail && !value.contains('@')) return 'Invalid email format';
              return null;
            },
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('Temporary Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(' *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (value) => (value == null || value.length < 6) ? 'Password must be at least 6 characters' : null,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, Map<String, int> items, int? currentValue, void Function(int?) onChanged, {bool isOptional = false, bool isRequired = false}) {
    List<DropdownMenuItem<int?>> dropdownItems = [];
    
    if (isOptional) {
      dropdownItems.add(const DropdownMenuItem(value: null, child: Text('None (Optional)', style: TextStyle(color: Colors.grey))));
    } else if (currentValue == null) {
      dropdownItems.add(const DropdownMenuItem(value: null, child: Text('Select...', style: TextStyle(color: Colors.grey))));
    }

    dropdownItems.addAll(
      items.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontSize: 15))))
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              if (isRequired) const Text(' *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
            ],
          ),
          const SizedBox(height: 8),
          
          DropdownButtonFormField<int?>(
            value: currentValue,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, color: Colors.grey),
            onChanged: onChanged,
            items: dropdownItems,
            validator: (value) {
              if (isRequired && value == null) {
                return 'This selection is required';
              }
              return null;
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}