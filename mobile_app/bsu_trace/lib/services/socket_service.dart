import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart'; 
import 'session_manager.dart';
import '../config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  io.Socket? _socket;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  io.Socket get socket {
    if (_socket == null) {
      initSocket();
    }
    return _socket!;
  }

  void initSocket() {
    if (_socket != null) return;

    String? token = SessionManager().sessionToken; 

    // STRIP '/api' if it exists in your config, because Socket.io runs on the root server
    String serverUrl = AppConfig.baseUrl.replaceAll('/api', '');

    debugPrint('Connecting Socket.IO to: $serverUrl');

    _socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer $token'}
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('🟢 Connected to Socket.IO Server successfully!'); 
    });

    _socket!.onConnectError((data) {
      debugPrint('🔴 Socket Connection Error: $data');
    });

    _socket!.onError((data) {
      debugPrint('🔴 Socket Error: $data');
    });

    _socket!.onDisconnect((_) {
      debugPrint('🟡 Disconnected from Socket.IO Server'); 
    });
  }

  void joinRoom(int iniId, int oId) {
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