import 'package:flutter/material.dart';
import '../models/user_role.dart';

class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  UserRole? _currentRole;
  int? _userId; // Add this to store the current user's ID

  UserRole? get currentRole => _currentRole;
  int? get userId => _userId; // Add a getter
  bool get isLoggedIn => _currentRole != null && _userId != null;

  // Update the login method to accept the userId
  void login(UserRole role, int userId) {
    _currentRole = role;
    _userId = userId;
    notifyListeners();
  }

  void logout() {
    _currentRole = null;
    _userId = null; // Clear the user ID on logout
    notifyListeners();
  }
}