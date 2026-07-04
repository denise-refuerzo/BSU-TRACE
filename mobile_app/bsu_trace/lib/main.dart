// lib/main.dart
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/session_manager.dart';
import 'models/user_role.dart';
import 'widgets/route_guard.dart';

// Screens
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scheduler_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/procurement_hub_screen.dart';
import 'screens/dashboard/user_dashboard.dart';
import 'screens/dashboard/processor_dashboard.dart';
import 'screens/dashboard/signee_dashboard.dart';
import 'screens/dashboard/gso_admin_dashboard.dart';
import 'screens/operational_analytics_screen.dart';
import 'screens/documents_screen.dart';
// --- FIX: Using an alias to prevent naming collisions ---
import 'screens/processing_history_screen.dart' as processor_history;
import 'screens/signee_pending_approvals_screen.dart';
import 'screens/signee_signature_history_screen.dart';
import 'screens/dashboard/ict_admin_dashboard.dart';
import 'screens/ict_admin_accounts_screen.dart';
import 'screens/ict_admin_roles_screen.dart';

void main() {
  runApp(const BsuPortalApp());
}

class BsuPortalApp extends StatelessWidget {
  const BsuPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
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
            '/dashboard_user': (context) => const RouteGuard(
              allowedRoles: [UserRole.user], child: UserDashboardScreen()),
            '/dashboard_processor': (context) => const RouteGuard(
              allowedRoles: [UserRole.processor], child: ProcessorDashboardScreen()),
            '/dashboard_signee': (context) => const RouteGuard(
              allowedRoles: [UserRole.signee], child: SigneeDashboardScreen()),
            '/dashboard_admin': (context) => const RouteGuard(
              allowedRoles: [UserRole.admin, UserRole.ictAdmin], child: AdminDashboardScreen()),
            '/tracking': (context) => const TrackingScreen(),
            '/scheduler': (context) => const SchedulerScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/procurement': (context) => const ProcurementHubScreen(),
            '/analytics': (context) => const OperationalAnalyticsScreen(),
            '/documents': (context) => const DocumentsScreen(),
            // --- FIX: Calling the route via the alias ---
            '/history': (context) => const processor_history.ProcessingHistoryScreen(),
            '/signee_approvals': (context) => const SigneePendingApprovalsScreen(),
            '/signee_history': (context) => const SigneeSignatureHistoryScreen(),
            // NEW: ICT Admin Routes
            '/dashboard_ict_admin': (context) => const RouteGuard(
              allowedRoles: [UserRole.ictAdmin], child: IctAdminDashboardScreen()),
            '/ict_admin_accounts': (context) => const RouteGuard(
              allowedRoles: [UserRole.ictAdmin], child: IctAdminAccountsScreen()),
            '/ict_admin_roles': (context) => const RouteGuard(
              allowedRoles: [UserRole.ictAdmin], child: IctAdminRolesScreen()),
          },
        );
      },
    );
  }
}