import 'package:flutter/material.dart';
import '../widgets/app_bar_helper.dart';
import 'office_chat_screen.dart';
import '../services/session_manager.dart';
import '../config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatChannelsScreen extends StatefulWidget {
  final int iniId;
  final String documentTitle;

  ChatChannelsScreen({required this.iniId, required this.documentTitle});

  @override
  _ChatChannelsScreenState createState() => _ChatChannelsScreenState();
}

class _ChatChannelsScreenState extends State<ChatChannelsScreen> {
  List<dynamic> officeChannels = []; 

  @override
  void initState() {
    super.initState();
    _fetchOfficeChannels();
  }

Future<void> _fetchOfficeChannels() async {
    final token = SessionManager().sessionToken;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chat/channels/${widget.iniId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            officeChannels = json.decode(response.body);
          });
        }
      } else {
        debugPrint('Failed to load channels');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Channels: ${widget.documentTitle}'),
      ),
      body: ListView.builder(
        itemCount: officeChannels.length,
        itemBuilder: (context, index) {
          final channel = officeChannels[index];
          final isLocked = channel['isLocked'];

          return ListTile(
            leading: Icon(
              isLocked ? Icons.lock_outline : Icons.forum,
              color: isLocked ? Colors.grey : Colors.green,
            ),
            title: Text(channel['office_name']),
            subtitle: Text(
              isLocked ? '[Read-Only Archive]' : '[Active]',
              style: TextStyle(
                color: isLocked ? Colors.grey : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OfficeChatScreen(
                    iniId: widget.iniId,
                    oId: channel['o_id'],
                    officeName: channel['office_name'],
                    documentTitle: widget.documentTitle,
                    isLocked: isLocked,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}