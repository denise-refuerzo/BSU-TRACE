import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationsDialog extends StatelessWidget {
  const NotificationsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data to match your image
    final List<Map<String, String>> notifications = [
      {'title': 'Quarterly Report Q3', 'subtitle': 'Awaiting Approval (Dean\'s Office)'},
      {'title': 'Faculty Loading Form', 'subtitle': 'Completed (Archive)'},
      {'title': 'Research Grant', 'subtitle': 'Sent from Registrar to VPAA Office'},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9F9), // Light background tint
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('DOCUMENT UPDATES', 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
            ),
            const Divider(height: 30, thickness: 1, color: Color(0xFFF0E0E0)),
            
            // List of items
            ...notifications.map((n) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(n['subtitle']!, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            )),
            
            const Divider(height: 30, thickness: 1, color: Color(0xFFF0E0E0)),
            
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                // Add your "View All" navigation logic here
              },
              child: const Text('View All Activity', 
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}