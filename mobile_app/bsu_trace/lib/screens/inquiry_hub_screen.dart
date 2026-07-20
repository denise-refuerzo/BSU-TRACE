import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/session_manager.dart';
import '../config.dart';
import 'chat_channels_screen.dart';

class InquiryHubScreen extends StatefulWidget {
  @override
  _InquiryHubScreenState createState() => _InquiryHubScreenState();
}

class _InquiryHubScreenState extends State<InquiryHubScreen> {
  List<dynamic> activeDocuments = [];
  bool isLoading = true;

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
        Uri.parse('${AppConfig.baseUrl}/chat/active-documents/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            activeDocuments = json.decode(response.body);
            isLoading = false;
          });
        }
      } else {
        debugPrint('Failed to load documents: ${response.statusCode}');
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inquiry Hub'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeDocuments.isEmpty
              ? const Center(
                  child: Text(
                    'No active document inquiries found.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: activeDocuments.length,
                  itemBuilder: (context, index) {
                    final doc = activeDocuments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(doc['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Status: ${doc['status']}'),
                        trailing: const Icon(Icons.chat_bubble_outline),
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