import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class Forgot2FAScreen extends StatefulWidget {
  final String? initialEmail; // Pass the email if they already typed it in login

  const Forgot2FAScreen({Key? key, this.initialEmail}) : super(key: key);

  @override
  _Forgot2FAScreenState createState() => _Forgot2FAScreenState();
}

class _Forgot2FAScreenState extends State<Forgot2FAScreen> {
  int _currentStep = 0; // 0: Email, 1: Code
  bool _isLoading = false;

  late TextEditingController _emailController;
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  Future<void> _sendRecoveryCode() async {
    if (_emailController.text.isEmpty) {
      _showMessage('Please enter your university email', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uni_email': _emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => _currentStep = 1);
        _showMessage(data['message']);
      } else {
        _showMessage(data['message'] ?? 'Error sending code', isError: true);
      }
    } catch (e) {
      _showMessage('Network error. Check your connection.', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _verifyAndDisable2FA() async {
    if (_codeController.text.length != 6) {
      _showMessage('Please enter the 6-digit code', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uni_email': _emailController.text.trim(),
          'code': _codeController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _showMessage('2FA Disabled Successfully! Please log in again.');
        // Pop back to the main login screen (pops both this screen and the 2FA modal)
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showMessage(data['message'] ?? 'Error verifying code', isError: true);
      }
    } catch (e) {
      _showMessage('Network error. Check your connection.', isError: true);
    }
    setState(() => _isLoading = false);
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2FA Recovery')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              
              if (_currentStep == 0) ...[
                const Text(
                  'Lost access to 2FA?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email to receive a recovery code. This will temporarily disable 2FA on your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'University Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _isLoading ? null : _sendRecoveryCode,
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send Recovery Code', style: TextStyle(fontSize: 16)),
                ),
              ],

              if (_currentStep == 1) ...[
                const Text(
                  'Enter Recovery Code',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a recovery code to ${_emailController.text}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit Code',
                    prefixIcon: Icon(Icons.password),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _isLoading ? null : _verifyAndDisable2FA,
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Disable 2FA & Recover Account', style: TextStyle(fontSize: 16)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}