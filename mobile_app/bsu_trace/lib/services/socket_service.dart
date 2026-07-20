import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart'; 
import 'session_manager.dart';
import '../config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late io.Socket socket;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  void initSocket() {
    // Accessing the synchronous getter from your Singleton
    String? token = SessionManager().sessionToken; 

    // Use AppConfig.baseUrl if you have it set up in config.dart
    socket = io.io('${AppConfig.baseUrl}', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer $token'}
    });

    socket.connect();

    socket.onConnect((_) {
      debugPrint('Connected to Socket.IO Server'); 
    });

    socket.onDisconnect((_) {
      debugPrint('Disconnected from Socket.IO Server'); 
    });
  }

  void joinRoom(int iniId, int oId) {
    socket.emit('join_room', {'ini_id': iniId, 'o_id': oId});
  }

  void leaveRoom(int iniId, int oId) {
    socket.emit('leave_room', {'ini_id': iniId, 'o_id': oId});
  }

  void dispose() {
    socket.disconnect();
  }
}