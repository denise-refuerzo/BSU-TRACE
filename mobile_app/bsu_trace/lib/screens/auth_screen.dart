import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  UserRole _selectedRole = UserRole.user;

  void _handleLogin() {
    currentUserRole = _selectedRole;
    switch (currentUserRole) {
      case UserRole.user: Navigator.pushReplacementNamed(context, '/dashboard_user'); break;
      case UserRole.processor: Navigator.pushReplacementNamed(context, '/dashboard_processor'); break;
      case UserRole.signee: Navigator.pushReplacementNamed(context, '/dashboard_signee'); break;
      case UserRole.admin: Navigator.pushReplacementNamed(context, '/dashboard_admin'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.school, color: AppTheme.primaryRed, size: 48),
              const SizedBox(height: 8),
              const Text('University Portal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
              const SizedBox(height: 4),
              const Text('BSU INSTITUTIONAL PORTAL', style: TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
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
                      _buildAuthTextField('University Email', 'name@university.edu', Icons.badge_outlined),
                      const SizedBox(height: 16),
                      _buildAuthTextField('Password', '••••••••', Icons.lock_outline, isPassword: true),
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
                                child: Text('Simulate Login As: ${role.name.toUpperCase()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
                              );
                            }).toList(),
                            onChanged: (UserRole? newValue) {
                              if (newValue != null) setState(() { _selectedRole = newValue; });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Align(alignment: Alignment.centerRight, child: Text('Forgot Password?', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12))),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('SIGN IN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('© 2026 University Institutional Portal. All rights reserved.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthTextField(String label, String hint, IconData? icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          obscureText: isPassword,
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