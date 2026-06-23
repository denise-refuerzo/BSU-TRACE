import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.user;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // 1. Force form validation
    // If validate() returns false, the function stops here immediately
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return; 
    }

    // 2. Proceed to Backend Verification
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authenticating...')));

    bool isAuthenticated = await _verifyUserCredentials(
      _emailController.text, 
      _passwordController.text, 
      _getAccountIdFromRole(_selectedRole)
    );

    if (isAuthenticated) {
      SessionManager().login(_selectedRole);

      switch (_selectedRole) {
        case UserRole.admin: Navigator.pushReplacementNamed(context, '/dashboard_admin'); break;
        case UserRole.processor: Navigator.pushReplacementNamed(context, '/dashboard_processor'); break;
        case UserRole.signee: Navigator.pushReplacementNamed(context, '/dashboard_signee'); break;
        case UserRole.user: Navigator.pushReplacementNamed(context, '/dashboard_user'); break;
      }
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid credentials or you do not have permission for this role.'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  int _getAccountIdFromRole(UserRole role) {
    switch (role) {
      case UserRole.user: return 1;
      case UserRole.processor: return 2;
      case UserRole.signee: return 3;
      case UserRole.admin: return 4;
    }
  }

  Future<bool> _verifyUserCredentials(String email, String password, int expectedAId) async {
    // REPLACE THIS WITH YOUR ACTUAL DATABASE/API LOGIC
    // Ensure you check: if (email == user.email && password == user.password && user.a_id == expectedAId)
    return true; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey, // Ensure the key is assigned here
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.school, color: AppTheme.primaryRed, size: 48),
                const SizedBox(height: 8),
                const Text('University Portal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
                const SizedBox(height: 40),
                
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('SIGN IN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryRed), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        
                        _buildAuthTextField('University Email', 'name@university.edu', Icons.badge_outlined, _emailController),
                        const SizedBox(height: 16),
                        _buildAuthTextField('Password', '••••••••', Icons.lock_outline, _passwordController, isPassword: true),
                        const SizedBox(height: 16),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<UserRole>(
                              value: _selectedRole,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryRed),
                              items: UserRole.values.map((UserRole role) {
                                return DropdownMenuItem<UserRole>(
                                  value: role,
                                  child: Text('Login As: ${role.name.toUpperCase()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
                                );
                              }).toList(),
                              onChanged: (UserRole? newValue) {
                                if (newValue != null) setState(() { _selectedRole = newValue; });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _handleLogin, // Triggers the validated function
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('SIGN IN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthTextField(String label, String hint, IconData? icon, TextEditingController controller, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          // This validator is what prevents submission on empty fields
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your $label';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: icon != null ? Icon(icon, color: Colors.brown) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade100)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryRed)),
            filled: true,
            fillColor: const Color(0xFFFFF9F9),
          ),
        ),
      ],
    );
  }
}