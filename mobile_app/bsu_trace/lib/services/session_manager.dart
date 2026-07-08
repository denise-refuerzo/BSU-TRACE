import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_role.dart';
import '../config.dart';
// 1. ADD THIS: Import main.dart to access the navigatorKey
import '../main.dart'; 

class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  UserRole? _currentRole;
  int? _userId; 
  String? _sessionToken;
  Timer? _sessionTimer;  

  UserRole? get currentRole => _currentRole;
  int? get userId => _userId; 
  String? get sessionToken => _sessionToken;
  bool get isLoggedIn => _currentRole != null && _userId != null && _sessionToken != null;

  void login(UserRole role, int userId, String sessionToken) {
    _currentRole = role;
    _userId = userId;
    _sessionToken = sessionToken;
    _startSessionChecker(); 
    notifyListeners();
  }

  void logout() {
    _currentRole = null;
    _userId = null; 
    _sessionToken = null;
    _sessionTimer?.cancel(); 
    notifyListeners();
  }

  void _startSessionChecker() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_userId == null || _sessionToken == null) {
        timer.cancel();
        return;
      }
      
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/check-session'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'u_id': _userId,
            'session_token': _sessionToken,
          }),
        );

        // 2. UPDATED: Force navigation and show an alert if token is invalid
        if (response.statusCode == 401) {
          logout(); // Clear local session data and stop timer
          
          // Ensure we have a valid context from our global key
          final context = navigatorKey.currentContext;
          if (context != null) {
            // Wipe the screen stack and go back to the AuthScreen
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
            
            // Show a dialog explaining why they were logged out
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Session Expired', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                content: const Text('Your account was logged in from another device. For your security, you have been logged out of this session.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        // Ignore network errors so the user stays logged in if they temporarily lose internet
      }
    });
  }
}