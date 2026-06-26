import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/session_manager.dart';

class RouteGuard extends StatelessWidget {
  final Widget child;
  final List<UserRole> allowedRoles;

  const RouteGuard({
    super.key, 
    required this.child, 
    required this.allowedRoles
  });

  @override
  Widget build(BuildContext context) {
    final session = SessionManager();
    
    // Check if logged in and role is permitted
    if (session.isLoggedIn && session.currentRole != null && allowedRoles.contains(session.currentRole)) {
      return child;
    }
    
    // If not authorized, redirect to login or show error
    return const Scaffold(
      body: Center(child: Text("Unauthorized Access")),
    );
  }
}