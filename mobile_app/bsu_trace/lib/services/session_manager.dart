import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_role.dart';
import '../config.dart';

class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  UserRole? _currentRole;
  int? _userId;
  String? _sessionToken; // Add token storage
  Timer? _sessionTimer; // Background timer to check session

  UserRole? get currentRole => _currentRole;
  int? get userId => _userId;
  String? get sessionToken => _sessionToken;
  bool get isLoggedIn =>
      _currentRole != null && _userId != null && _sessionToken != null;

  // Accept the sessionToken upon login
  void login(UserRole role, int userId, String sessionToken) {
    _currentRole = role;
    _userId = userId;
    _sessionToken = sessionToken;
    _startSessionChecker(); // Start tracking
    notifyListeners();
  }

  void logout() {
    _currentRole = null;
    _userId = null;
    _sessionToken = null;
    _sessionTimer?.cancel(); // Stop tracking
    notifyListeners();
  }

  // Polls the server every 10 seconds to ensure the token hasn't changed
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
          body: json.encode({'u_id': _userId, 'session_token': _sessionToken}),
        );

        // If server returns 401, another device logged in
        if (response.statusCode == 401) {
          logout();
          // Because SessionManager is a ChangeNotifier, your route_guard or main.dart
          // will detect the logout and push the user back to the AuthScreen automatically.
        }
      } catch (e) {
        // Ignore network errors (keep session alive if offline temporarily)
      }
    });
  }
}
