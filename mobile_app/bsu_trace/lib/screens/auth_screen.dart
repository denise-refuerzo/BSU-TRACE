// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'package:bsu_trace/screens/forgot_password_screen.dart';
import 'forgot_2fa_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Separated dashboard navigation logic so we can call it after 2FA
  void _proceedToDashboard(UserRole role, int userId) {
    SessionManager().login(role, userId);

    switch (role) {
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
  }

  // Displays the 2FA input modal and verifies it with the backend
  Future<void> _showVerify2FAModal(UserRole role, int userId) async {
    final TextEditingController pinController = TextEditingController();
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('2-Step Verification', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter the 6-digit PIN you configured in your profile.'),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter PIN',
                    filled: true,
                    fillColor: Colors.red.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Close the 2FA modal first
                  Navigator.pop(context); 

                  // Navigate to the recovery screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Forgot2FAScreen(
                        // Pass the email controller's text from your login form so they don't have to type it again
                        initialEmail: _emailController.text, 
                      ),
                    ),
                  );
                },
                child: const Text('Lost access to 2FA?'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                onPressed: isVerifying ? null : () async {
                  setModalState(() => isVerifying = true);
                  
                  try {
                    final res = await http.post(
                      Uri.parse('${AppConfig.baseUrl}/verify-2fa'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({'u_id': userId, 'code': pinController.text})
                    );
                    
                    if (!mounted) return;

                    if (res.statusCode == 200) {
                      Navigator.pop(context); // Close modal
                      _proceedToDashboard(role, userId); // Proceed to dashboard
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN. Access Denied.'), backgroundColor: Colors.red));
                      setModalState(() => isVerifying = false);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.'), backgroundColor: Colors.red));
                    setModalState(() => isVerifying = false);
                  }
                },
                child: isVerifying 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Verify', style: TextStyle(color: Colors.white))
              )
            ]
          );
        }
      )
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
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
        final bool is2faEnabled = data['two_fa_enabled'] ?? false; 
        
        // Automatically determine the role based on the backend's account ID (a_id)
        final UserRole actualRole = accountId.toRole();

        if (!mounted) return;
        setState(() => _isLoading = false); 

        // INTERCEPT NAVIGATION FOR 2FA
        if (is2faEnabled) {
          _showVerify2FAModal(actualRole, userId);
        } else {
          _proceedToDashboard(actualRole, userId);
        }

      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error. Please check your network.')),
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
                                                 
                        _buildAuthTextField('Username', ' ', Icons.badge_outlined, _emailController),
                        const SizedBox(height: 16),
                        _buildAuthTextField('Password', ' ', Icons.lock_outline, _passwordController, isPassword: true),
                        const SizedBox(height: 8),
                                                 
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                              );
                            },
                            child: const Text('Forgot Password?'),
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