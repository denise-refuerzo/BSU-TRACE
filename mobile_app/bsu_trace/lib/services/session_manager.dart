// lib/services/session_manager.dart
import 'package:flutter/material.dart';
import '../models/user_role.dart';

class SessionManager extends ChangeNotifier {
  // Singleton pattern for easy access throughout the app
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  UserRole _currentUserRole = UserRole.user;

  UserRole get currentRole => _currentUserRole;

  void login(UserRole role) {
    _currentUserRole = role;
    notifyListeners(); // Triggers UI updates across the app
  }

  void logout() {
    _currentUserRole = UserRole.user; // Default back to user
    notifyListeners();
  }

  bool hasAccess(List<UserRole> allowedRoles) {
    return allowedRoles.contains(_currentUserRole);
  }
}