// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  UserRole? _selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your designated role from the dropdown.')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'username': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int accountId = data['a_id'];
        final int userId = data['u_id'];
        
        final UserRole actualRole = accountId.toRole();

        if (actualRole != _selectedRole) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role mismatch. Please select your correct designated role.')),
          );
          return;
        }

        SessionManager().login(actualRole, userId);

        if (!mounted) return;

        switch (actualRole) {
          case UserRole.admin: 
            Navigator.pushReplacementNamed(context, '/dashboard_admin'); 
            break;
          case UserRole.processor: 
            Navigator.pushReplacementNamed(context, '/dashboard_processor'); 
            break;
          case UserRole.signee: 
            Navigator.pushReplacementNamed(context, '/dashboard_signee'); 
            break;
          default: 
            Navigator.pushReplacementNamed(context, '/dashboard_user'); 
            break;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials or unauthorized role.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.school, color: AppTheme.primaryRed, size: 48),
                const Text(
                  'University Portal', 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                ),
                const SizedBox(height: 40),
                                 
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'SIGN IN', 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryRed), 
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                                                 
                        _buildAuthTextField('University Email', 'name@university.edu', Icons.badge_outlined, _emailController),
                        const SizedBox(height: 16),
                        _buildAuthTextField('Password', ' ', Icons.lock_outline, _passwordController, isPassword: true),
                        const SizedBox(height: 16),
                                                 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50, 
                            borderRadius: BorderRadius.circular(8), 
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<UserRole>(
                              value: _selectedRole,
                              isExpanded: true,
                              hint: const Text(
                                'Select Designated Role', 
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                              ),
                              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryRed),
                              items: UserRole.values.map((UserRole role) {
                                // Intercept "USER" and display it as "ORIGINATOR"
                                String displayRole = role.name.toUpperCase();
                                if (displayRole == 'USER') {
                                  displayRole = 'ORIGINATOR';
                                }

                                return DropdownMenuItem<UserRole>(
                                  value: role,
                                  child: Text(
                                    'Login As: $displayRole', 
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                                  ),
                                );
                              }).toList(),
                              onChanged: (UserRole? newValue) {
                                if (newValue != null) {
                                  setState(() { _selectedRole = newValue; });
                                }
                              },
                            ),
                          ),
                        ),
                                                 
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () { /* Navigate to forgot password screen */ },
                            child: const Text(
                              'Forgot Password?', 
                              style: TextStyle(color: AppTheme.primaryRed, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        ElevatedButton(
                          onPressed: _isLoading ? () {} : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed, 
                            padding: const EdgeInsets.symmetric(vertical: 16), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isLoading 
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SIGN IN', 
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
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

  Widget _buildAuthTextField(
    String label, 
    String hint, 
    IconData? icon, 
    TextEditingController controller, 
    {bool isPassword = false}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          validator: (value) => (value == null || value.isEmpty) ? 'Please enter your $label' : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, color: Colors.brown) : null,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.brown,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), 
              borderSide: BorderSide(color: Colors.red.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), 
              borderSide: const BorderSide(color: AppTheme.primaryRed),
            ),
            filled: true,
            fillColor: const Color(0xFFFFF9F9),
          ),
        ),
      ],
    );
  }
}