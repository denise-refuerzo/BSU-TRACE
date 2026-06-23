import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/notifications_dialog.dart';

// Note: Ensure your NotificationsDialog is imported if you move it to a separate file
// import '../widgets/dialogs/notifications_dialog.dart';

List<Widget> buildAppBarActions(BuildContext context) {
  return [
    IconButton(
      icon: const Icon(Icons.notifications_none, color: AppTheme.primaryRed),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const NotificationsDialog(),
        );
      },
    ),
    PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined, color: Colors.grey),
      onSelected: (value) {
        if (value == 'profile') {
          Navigator.pushNamed(context, '/profile');
        } else if (value == 'logout') {
          // Clear any auth tokens here if necessary before navigating
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, color: Colors.black54, size: 20),
              SizedBox(width: 8),
              Text('My Profile'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: AppTheme.primaryRed, size: 20),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    ),
  ];
}