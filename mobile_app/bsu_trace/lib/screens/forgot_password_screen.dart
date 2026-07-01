import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart'; // Imports the API URL mapping

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 0; // 0: Email, 1: Code/New Password[cite: 1]
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  Future<void> _sendCode() async {
    setState(() => _isLoading = true);
    try {
      // FIX: Removed the duplicate '/api' since AppConfig.baseUrl already includes it[cite: 1]
      final url = Uri.parse('${AppConfig.baseUrl}/auth/forgot-password');
      
      debugPrint('Sending request to: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        // FIX: Changed 'bsutrace@gmail.com' back to a standard payload key 'email'[cite: 1]
        body: jsonEncode({'email': _emailController.text.trim()}),
      ).timeout(
        const Duration(seconds: 30), // Protects against live Render server sleep hanging
      );

      // Diagnostic logging to reveal any HTML error bodies safely
      debugPrint('HTTP Status Code: ${response.statusCode}');
      debugPrint('HTTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _currentStep = 1);
        _showMessage(data['message'] ?? 'Reset code sent successfully!');
      } else {
        // Safe check if the server actually returned JSON or an error message string
        try {
          final data = jsonDecode(response.body);
          _showMessage(data['message'] ?? 'Error sending code', isError: true);
        } catch (_) {
          _showMessage('Server Error (${response.statusCode}). Check Render backend logs.', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Send Code Error Exception: $e');
      _showMessage('Connection error or timeout. Please check your network.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.length < 6) {
      _showMessage('Password must be at least 6 characters', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      // FIX: Removed duplicate '/api'[cite: 1]
      final url = Uri.parse('${AppConfig.baseUrl}/auth/forgot-password');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        // FIX: Replaced explicit config values with structural JSON key identifiers[cite: 1]
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'code': _codeController.text.trim(),
          'newPassword': _newPasswordController.text, 
        }),
      ).timeout(
        const Duration(seconds: 30),
      );

      debugPrint('HTTP Status Code: ${response.statusCode}');
      debugPrint('HTTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        _showMessage('Password successfully reset! Please login.');
        Navigator.pop(context); // Navigates back to AuthScreen login layout[cite: 1]
      } else {
        try {
          final data = jsonDecode(response.body);
          _showMessage(data['message'] ?? 'Error resetting password', isError: true);
        } catch (_) {
          _showMessage('Failed to complete reset pattern configuration.', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Reset Password Error Exception: $e');
      _showMessage('Network connection problem. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            if (_currentStep == 0) ...[
              const Text('Enter your University Email to receive a reset code.'),
              const SizedBox(height: 15),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'University Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendCode,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('Send Code'),
              ),
            ],
            
            if (_currentStep == 1) ...[
              Text('Enter the code sent to ${_emailController.text} and your new password.'),
              const SizedBox(height: 15),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '6-digit Reset Code',
                  prefixIcon: Icon(Icons.security),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('Reset Password'),
              ),
              TextButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Back to Email'),
              )
            ],
          ],
        ),
      ),
    );
  }
}