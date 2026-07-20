import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/session_manager.dart';

class AppDrawer extends StatelessWidget {
  final Future<bool> Function()? onBeforeNavigate;

  const AppDrawer({super.key, this.onBeforeNavigate});

  @override
  Widget build(BuildContext context) {
    final currentRole = SessionManager().currentRole;
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    Widget buildNavItem({required String title, required IconData icon, required String route, bool isPlaceholder = false}) {
      bool isSelected = currentRoute == route;
      if (isPlaceholder && route.isEmpty) isSelected = false;

      return InkWell(
        onTap: () async {
          Navigator.pop(context); 

          if (!isPlaceholder) {
            if (route.isNotEmpty && currentRoute != route) {
              
              bool shouldProceed = true;
              if (onBeforeNavigate != null) {
                shouldProceed = await onBeforeNavigate!();
              }

              if (shouldProceed && context.mounted) {
                if (route.contains('dashboard')) {
                  Navigator.pushReplacementNamed(context, route);
                } else {
                  Navigator.pushNamed(context, route);
                }
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title coming soon...'), duration: const Duration(seconds: 1)));
          }
        },
        child: Container(
          color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 4,
                height: 52,
                color: isSelected ? const Color(0xFFB01A22) : Colors.transparent
              ),
              const SizedBox(width: 20),
              Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14
                )
              ),
            ],
          ),
        ),
      );
    }

    Widget buildBottomItem({required String title, required IconData icon, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    String roleTitle = 'USER PORTAL';
    String userInitials = 'U';
    String userName = 'John Doe';
    String roleSubtitle = 'FACULTY MEMBER';

    if (currentRole == UserRole.admin) {
      roleTitle = 'GSO ADMINISTRATION';
      userInitials = 'GA';
      userName = 'Admin User';
      roleSubtitle = 'GSO ADMINISTRATOR';
    } else if (currentRole == UserRole.ictAdmin) {
      roleTitle = 'SYSTEM ADMINISTRATION';
      userInitials = 'IA';
      userName = 'System Admin';
      roleSubtitle = 'ICT ADMINISTRATOR';
    } else if (currentRole == UserRole.processor) {
      roleTitle = 'PROCESSOR PORTAL';
      userInitials = 'P';
      userName = 'Processor User';
      roleSubtitle = 'DOCUMENT PROCESSOR';
    } else if (currentRole == UserRole.signee) {
      roleTitle = 'SIGNEE PORTAL';
      userInitials = 'S';
      userName = 'Signee User';
      roleSubtitle = 'AUTHORIZED SIGNEE';
    }

    return Drawer(
      backgroundColor: const Color(0xFF3D2D2D),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BSU Portal', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(roleTitle, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (currentRole == UserRole.admin) ...[
                    buildNavItem(title: 'Dashboard', icon: Icons.grid_view, route: '/dashboard_admin'),
                    buildNavItem(title: 'Scan In/Out', icon: Icons.qr_code_scanner, route: '/documents'),
                    buildNavItem(title: 'Pending Signatures', icon: Icons.fact_check_outlined, route: '/signee_approvals'),
                    buildNavItem(title: 'School Resources', icon: Icons.school_outlined, route: '/scheduler'),
                    buildNavItem(title: 'Procurement', icon: Icons.shopping_cart_outlined, route: '/procurement'),
                    buildNavItem(title: 'Operational Analytics', icon: Icons.insert_chart_outlined, route: '/analytics'),
                    buildNavItem(title: 'Scan History', icon: Icons.history, route: '/history'),
                    buildNavItem(title: 'Signature History', icon: Icons.history_edu, route: '/signee_history'),
                    buildNavItem(title: 'Inquiry Hub', icon: Icons.chat_bubble_outline, route: '/inquiry_hub'),
                  ] else if (currentRole == UserRole.ictAdmin) ...[
                    buildNavItem(title: 'Dashboard', icon: Icons.grid_view, route: '/dashboard_ict_admin'),
                    buildNavItem(title: 'Accounts', icon: Icons.people_outline, route: '/ict_admin_accounts'),
                    buildNavItem(title: 'Roles & Matrix', icon: Icons.security, route: '/ict_admin_roles'),
                  ] else if (currentRole == UserRole.user) ...[
                    buildNavItem(title: 'Dashboard', icon: Icons.grid_view, route: '/dashboard_user'),
                    buildNavItem(title: 'Live Tracking', icon: Icons.track_changes, route: '/tracking'),
                    buildNavItem(title: 'Resource Scheduler', icon: Icons.calendar_month, route: '/scheduler'),
                    buildNavItem(title: 'Inquiry Hub', icon: Icons.chat_bubble_outline, route: '/inquiry_hub'),
                  ] else if (currentRole == UserRole.processor) ...[
                     buildNavItem(title: 'Dashboard', icon: Icons.grid_view, route: '/dashboard_processor'),
                     buildNavItem(title: 'Documents', icon: Icons.description_outlined, route: '/documents'),
                     buildNavItem(title: 'History', icon: Icons.history, route: '/history'),
                     buildNavItem(title: 'Inquiry Hub', icon: Icons.chat_bubble_outline, route: '/inquiry_hub'),
                  ] else if (currentRole == UserRole.signee) ...[
                    buildNavItem(title: 'Dashboard', icon: Icons.grid_view, route: '/dashboard_signee'),
                    buildNavItem(title: 'Pending Approvals', icon: Icons.fact_check_outlined, route: '/signee_approvals'),
                    buildNavItem(title: 'Signature History', icon: Icons.history_edu, route: '/signee_history'),
                    buildNavItem(title: 'Inquiry Hub', icon: Icons.chat_bubble_outline, route: '/inquiry_hub'),
                  ],
                ],
              ),
            ),
            
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFB01A22), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(userInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(roleSubtitle, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            buildBottomItem(title: 'Logout', icon: Icons.logout, onTap: () async {
              Navigator.pop(context); 
              
              bool shouldProceed = true;
              if (onBeforeNavigate != null) {
                 shouldProceed = await onBeforeNavigate!();
              }

              if (shouldProceed && context.mounted) {
                 SessionManager().logout();
                 Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}