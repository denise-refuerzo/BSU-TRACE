import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart'; 
import 'session_manager.dart';
import '../config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  
  // 1. Change from 'late' to a nullable private variable
  io.Socket? _socket;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  // 2. Add a getter that automatically initializes the socket if it hasn't been yet
  io.Socket get socket {
    if (_socket == null) {
      initSocket();
    }
    return _socket!;
  }

  void initSocket() {
    // Prevent duplicate initializations
    if (_socket != null) return;

    String? token = SessionManager().sessionToken; 

    _socket = io.io('${AppConfig.baseUrl}', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer $token'}
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('Connected to Socket.IO Server'); 
    });

    _socket!.onDisconnect((_) {
      debugPrint('Disconnected from Socket.IO Server'); 
    });
  }

  void joinRoom(int iniId, int oId) {
    // This will now trigger the 'get socket' method, safely auto-initializing if needed
    socket.emit('join_room', {'ini_id': iniId, 'o_id': oId});
  }

  void leaveRoom(int iniId, int oId) {
    socket.emit('leave_room', {'ini_id': iniId, 'o_id': oId});
  }

  void dispose() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }
}