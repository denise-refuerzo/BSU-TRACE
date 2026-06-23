// lib/services/session_manager.dart
import 'package:flutter/material.dart';
import '../models/user_role.dart';

class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  UserRole? _currentRole;
  
  UserRole? get currentRole => _currentRole;
  bool get isLoggedIn => _currentRole != null;

  void login(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void logout() {
    _currentRole = null;
    notifyListeners();
  }
}