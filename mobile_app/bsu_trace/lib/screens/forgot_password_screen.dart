import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart'; // Adjust path based on where your API URL is stored

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 0; // 0: Email, 1: Code, 2: New Password
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

Future<void> _sendCode() async {
  setState(() => _isLoading = true);
  try {
    final response = await http.post(
      // Ensure this points cleanly to your endpoint without duplicating '/api'
      Uri.parse('${AppConfig.baseUrl}/auth/forgot-password'), 
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uni_email': _emailController.text.trim(), // FIXED: Key changed to 'uni_email'
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      setState(() => _currentStep = 1);
      _showMessage(data['message']);
    } else {
      _showMessage(data['message'] ?? 'Error sending code', isError: true);
    }
  } catch (e) {
    _showMessage('Network error. Please try again.', isError: true);
  }
  setState(() => _isLoading = false);
}

Future<void> _resetPassword() async {
  if (_newPasswordController.text.length < 6) {
    _showMessage('Password must be at least 6 characters', isError: true);
    return;
  }
  setState(() => _isLoading = true);
  try {
    final response = await http.post(
      // FIXED: Endpoint target path changed to 'reset-password'
      Uri.parse('${AppConfig.baseUrl}/auth/reset-password'), 
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uni_email': _emailController.text.trim(),   // FIXED: Key changed to 'uni_email'
        'code': _codeController.text.trim(),         // Key matches backend 'code'
        'new_password': _newPasswordController.text, // FIXED: Key changed to 'new_password'
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _showMessage('Password successfully reset! Please login.');
      Navigator.pop(context); // Head back to login screen safely
    } else {
      _showMessage(data['message'] ?? 'Error resetting password', isError: true);
    }
  } catch (e) {
    _showMessage('Network error. Please try again.', isError: true);
  }
  setState(() => _isLoading = false);
}

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
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
                    ? const CircularProgressIndicator(color: Colors.white)
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
                    ? const CircularProgressIndicator(color: Colors.white)
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