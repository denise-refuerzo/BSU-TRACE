// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'package:bsu_trace/screens/forgot_password_screen.dart';

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
      case UserRole.ictAdmin: // <-- ADD THIS CASE
        Navigator.pushReplacementNamed(context, '/dashboard_ict_admin'); 
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
Future<void> _showVerify2FAModal(UserRole actualRole, int userId) {
    final TextEditingController pinController = TextEditingController();
    bool isVerifying = false;
    int failedAttempts = 0; // Tracks failed attempts locally

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          
          Future<void> verifyPin() async {
            if (pinController.text.length != 6) return;
            
            setModalState(() => isVerifying = true);
            
            try {
              final response = await http.post(
                Uri.parse('${AppConfig.baseUrl}/verify-2fa'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'u_id': userId,
                  'code': pinController.text,
                }),
              );

              if (response.statusCode == 200) {
                 Navigator.pop(context); // Close modal
                 _proceedToDashboard(actualRole, userId);
              } else if (response.statusCode == 401) {
                 final data = json.decode(response.body);
                 
                 setModalState(() {
                   isVerifying = false;
                   failedAttempts++; // Increment attempt
                   pinController.clear();
                 });
                 
                 // If backend sent the new PIN email (10 limits hit)
                 if (data['error'].contains('A NEW PIN has been sent')) {
                     Navigator.pop(context);
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                       content: Text(data['error']), 
                       backgroundColor: Colors.orange.shade800, 
                       duration: const Duration(seconds: 5)
                     ));
                 }
              }
            } catch (e) {
               setModalState(() => isVerifying = false);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error')));
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Two-Factor Authentication', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please enter your 6-digit PIN to continue.'),
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
                
                // ADDED: The dynamic countdown text below the field
                if (failedAttempts >= 5 && failedAttempts < 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'You have ${10 - failedAttempts} attempts left',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cancel
                  SessionManager().logout();
                }, 
                child: const Text('Cancel')
              ),
              ElevatedButton(
                onPressed: isVerifying ? null : verifyPin,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB01A22)),
                child: isVerifying 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      )
    );
  }

Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false); 

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int accountId = data['a_id'];
        final int userId = data['u_id'];
        final bool is2faEnabled = data['two_fa_enabled'] ?? false; 
        
        final UserRole actualRole = accountId.toRole();

        if (is2faEnabled) {
          _showVerify2FAModal(actualRole, userId);
        } else {
          _proceedToDashboard(actualRole, userId);
        }
      } else if (response.statusCode == 403) {
        // CATCH RESTRICTED ACCOUNTS HERE
        final errorMsg = json.decode(response.body)['error'];
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.orange.shade800, duration: const Duration(seconds: 4)),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error. Please check your network.'), backgroundColor: Colors.red),
      );
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