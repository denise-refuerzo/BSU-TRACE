import 'package:flutter/material.dart';
import '../widgets/app_bar_helper.dart';
import 'chat_channels_screen.dart';
import '../services/session_manager.dart';
import '../config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class InquiryHubScreen extends StatefulWidget {
  @override
  _InquiryHubScreenState createState() => _InquiryHubScreenState();
}

class _InquiryHubScreenState extends State<InquiryHubScreen> {
  List<dynamic> activeDocuments = []; // Populate via your API

  @override
  void initState() {
    super.initState();
    _fetchActiveDocuments();
  }

Future<void> _fetchActiveDocuments() async {
    final userId = SessionManager().userId;
    final token = SessionManager().sessionToken;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/chat/active-documents/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            activeDocuments = json.decode(response.body);
          });
        }
      } else {
        debugPrint('Failed to load documents');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inquiry Hub')),
      body: ListView.builder(
        itemCount: activeDocuments.length,
        itemBuilder: (context, index) {
          final doc = activeDocuments[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(doc['title'], style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Status: ${doc['status']}'),
              trailing: Icon(Icons.chat_bubble_outline),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatChannelsScreen(
                      iniId: doc['ini_id'],
                      documentTitle: doc['title'],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}