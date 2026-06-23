// lib/main.dart
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/session_manager.dart'; 

// Screens
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scheduler_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/procurement_hub_screen.dart';
import 'screens/dashboard/user_dashboard.dart';
import 'screens/dashboard/processor_dashboard.dart';
import 'screens/dashboard/signee_dashboard.dart';
import 'screens/dashboard/admin_dashboard.dart';
import 'screens/operational_analytics_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/processing_history_screen.dart';
import 'screens/signee_pending_approvals_screen.dart';
import 'screens/signee_signature_history_screen.dart';

void main() {
  runApp(const BsuPortalApp());
}

class BsuPortalApp extends StatelessWidget {
  const BsuPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder makes the app reactive to session changes
    return ListenableBuilder(
      listenable: SessionManager(),
      builder: (context, _) {
        return MaterialApp(
          title: 'University Portal',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthScreen(),
            '/dashboard_user': (context) => const UserDashboardScreen(),
            '/dashboard_processor': (context) => const ProcessorDashboardScreen(),
            '/dashboard_signee': (context) => const SigneeDashboardScreen(),
            '/dashboard_admin': (context) => const AdminDashboardScreen(),
            '/tracking': (context) => const TrackingScreen(),
            '/scheduler': (context) => const SchedulerScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/procurement': (context) => const ProcurementHubScreen(),
            '/analytics': (context) => const OperationalAnalyticsScreen(),
            '/documents': (context) => const DocumentsScreen(),
            '/history': (context) => const ProcessingHistoryScreen(),
            '/signee_approvals': (context) => const SigneePendingApprovalsScreen(),
            '/signee_history': (context) => const SigneeSignatureHistoryScreen(),
          },
        );
      },
    );
  }
}