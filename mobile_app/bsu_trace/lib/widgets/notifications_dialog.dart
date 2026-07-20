import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Added for local read state

import '../services/session_manager.dart';
import '../config.dart';
import '../screens/document_details_screen.dart';

class NotificationsDialog extends StatefulWidget {
  const NotificationsDialog({super.key});

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  Set<String> _readDocIds = {}; // Tracks which documents have been read

  @override
  void initState() {
    super.initState();
    _loadReadStatus(); // Load the read history when dialog opens
    _fetchNotifications();
  }

  // Fetch the saved read IDs from local storage
  Future<void> _loadReadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readDocIds = (prefs.getStringList('read_notifications') ?? []).toSet();
    });
  }

  // Add the ID to the read list and save it locally
  Future<void> _markAsRead(String id) async {
    if (!_readDocIds.contains(id)) {
      setState(() {
        _readDocIds.add(id);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_notifications', _readDocIds.toList());
    }
  }

  Future<void> _fetchNotifications() async {
    final userId = SessionManager().userId;
    
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/users/$userId/documents'));

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> docs = json.decode(response.body);
        
        setState(() {
          _notifications = docs.take(5).toList(); 
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatActionMessage(Map<String, dynamic> doc) {
    final status = (doc['status'] ?? 'updated').toString().toLowerCase();
    final location = doc['current_location'] ?? 'an unknown office';
    final title = doc['title'] ?? 'Untitled Document';

    if (status == 'pending') {
      return 'Your document "$title" is currently pending at the $location.';
    } else if (status == 'action required') {
      return 'Action is required for your document "$title" at the $location.';
    } else if (status == 'completed' || status == 'approved') {
      return 'Great news! Your document "$title" has been $status.';
    } else if (status == 'in verification') {
      return 'Your document "$title" is currently undergoing verification at the $location.';
    } else {
      return 'Your document "$title" was marked as $status at the $location.';
    }
  }

  String _timeAgo(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'Recently';
    
    try {
      final date = DateTime.parse(dateTimeStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 1) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  IconData _getIconForStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'approved' || s == 'verified' || s == 'signed') return Icons.check_circle;
    if (s == 'action required') return Icons.error;
    return Icons.schedule; 
  }

  Color _getColorForStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'approved' || s == 'verified' || s == 'signed') return Colors.green;
    if (s == 'action required') return Colors.red;
    return Colors.orange; 
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9F9), 
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'LATEST UPDATES', 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)
              ),
            ),
            const Divider(height: 30, thickness: 1, color: Color(0xFFF0E0E0)),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(30.0),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFB01A22))),
              )
            else if (_notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30.0),
                child: Center(
                  child: Text('No new notifications.', style: TextStyle(color: Colors.black54))
                ),
              )
            else
              ..._notifications.map((n) {
                final status = n['status'] ?? 'Unknown';
                final timeString = n['time_in'] ?? n['updated_at'] ?? n['created_at']; 
                final documentId = n['ini_id']; 
                
                final String docIdStr = documentId.toString();
                // Check if the current document ID exists in our read list
                final bool isUnread = !_readDocIds.contains(docIdStr);

                return Material(
                  // Apply a subtle red highlight if unread, otherwise transparent
                  color: isUnread ? const Color(0xFFFDE8E8) : Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // 1. Mark as read immediately to remove the highlight
                      _markAsRead(docIdStr);

                      // 2. Close the dialog
                      Navigator.pop(context);
                      
                      // 3. Navigate to the document details screen
                      if (documentId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DocumentDetailsScreen(
                              docId: documentId,
                            ),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              _getIconForStatus(status), 
                              color: _getColorForStatus(status), 
                              size: 22
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatActionMessage(n),
                                  style: TextStyle(
                                    fontSize: 13, 
                                    color: Colors.black87, 
                                    height: 1.3,
                                    // Make text bold if unread for extra emphasis
                                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _timeAgo(timeString),
                                  style: TextStyle(
                                    // Make timestamp slightly darker if unread
                                    color: isUnread ? Colors.black87 : Colors.black54, 
                                    fontSize: 11, 
                                    fontWeight: FontWeight.w500
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            
            const Divider(height: 30, thickness: 1, color: Color(0xFFF0E0E0)),
            
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'Close', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB01A22), fontWeight: FontWeight.bold, fontSize: 14)
              ),
            ),
          ],
        ),
      ),
    );
  }
}