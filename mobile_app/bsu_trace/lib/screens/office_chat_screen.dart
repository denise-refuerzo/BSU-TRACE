import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/socket_service.dart';
import '../services/session_manager.dart';

class OfficeChatScreen extends StatefulWidget {
  final int iniId;
  final int oId;
  final String officeName;
  final String documentTitle;
  final bool isLocked;

  const OfficeChatScreen({
    Key? key,
    required this.iniId,
    required this.oId,
    required this.officeName,
    required this.documentTitle,
    required this.isLocked,
  }) : super(key: key);

  @override
  _OfficeChatScreenState createState() => _OfficeChatScreenState();
}

class _OfficeChatScreenState extends State<OfficeChatScreen> {
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> messages = [];
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _socketService.joinRoom(widget.iniId, widget.oId);
    _setupSocketListeners();
    _fetchChatHistory();
  }

  void _loadCurrentUser() {
    // Accessing the synchronous getter from your Singleton
    setState(() {
      currentUserId = SessionManager().userId;
    });
  }

  Future<void> _fetchChatHistory() async {
    // TODO: HTTP GET request to your Node.js backend to fetch existing chat history
    // Endpoint example: /api/chat/${widget.iniId}/${widget.oId}
  }

  void _setupSocketListeners() {
    _socketService.socket.on('receive_message', (data) {
      if (mounted) {
        setState(() {
          messages.add(data);
        });
        _scrollToBottom();
      }
    });

    _socketService.socket.on('room_locked', (_) {
      if (mounted && !widget.isLocked) {
        setState(() {
          // Trigger a rebuild to disable input fields
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This chat has been locked as the document moved.')),
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageData = {
      'ini_id': widget.iniId,
      'o_id': widget.oId,
      'sender_id': currentUserId,
      'message_text': _messageController.text.trim(),
      'sent_at': DateTime.now().toIso8601String(),
    };

    _socketService.socket.emit('send_message', messageData);

    setState(() {
      messages.add(messageData);
    });

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _socketService.leaveRoom(widget.iniId, widget.oId);
    _socketService.socket.off('receive_message');
    _socketService.socket.off('room_locked');
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.documentTitle, style: const TextStyle(fontSize: 16)),
            Text(
              widget.officeName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.isLocked)
            Container(
              width: double.infinity,
              color: Colors.grey[300],
              padding: const EdgeInsets.all(8),
              child: Text(
                'Read-Only Archive. This document has moved to the next station or is beyond the 24-hour grace period.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['sender_id'] == currentUserId;
                
                DateTime sentAt = DateTime.parse(msg['sent_at']);
                String timeString = DateFormat('hh:mm a').format(sentAt);

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFB01A22) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['message_text'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeString,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !widget.isLocked, 
                decoration: InputDecoration(
                  hintText: widget.isLocked 
                      ? 'Chat locked...' 
                      : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: widget.isLocked ? Colors.grey : const Color(0xFFB01A22),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: widget.isLocked ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}