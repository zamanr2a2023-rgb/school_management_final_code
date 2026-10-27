import 'dart:async';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/domain/entities/class_chat_message_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket.IO client for class chat realtime events.
class ClassChatSocketClient {
  ClassChatSocketClient(this._prefs);

  final SharedPreferences _prefs;
  io.Socket? _socket;
  final _controller = StreamController<ClassChatMessageEntity>.broadcast();
  final _inAppNotifyController =
      StreamController<ClassChatInAppNotifyEvent>.broadcast();
  final _deletedController = StreamController<({String classId, String id})>.broadcast();
  String? _joinedClassId;

  /// Realtime in-app alert while the user is anywhere in the app (user socket room).
  Stream<ClassChatInAppNotifyEvent> get inAppNotifications =>
      _inAppNotifyController.stream;

  Stream<ClassChatMessageEntity> get messages => _controller.stream;

  Stream<({String classId, String id})> get deletedMessages =>
      _deletedController.stream;

  String get _socketUrl {
    final base = AppConstants.apiBaseUrl.trim();
    if (base.isEmpty) return '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  String? get _token => _prefs.getString(AppConstants.sessionTokenKey);

  /// Connect socket (joins user room on server) for global in-app chat alerts.
  Future<void> ensureConnected() async {
    final url = _socketUrl;
    final token = _token;
    if (url.isEmpty || token == null || token.isEmpty) return;

    if (_socket == null) {
      _attachSocket(io.io(
        url,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      ));
    }

    if (!_socket!.connected) {
      _socket!.connect();
    }
  }

  Future<void> connectAndJoin(String classId) async {
    if (classId.isEmpty) return;
    await ensureConnected();
    if (_socket!.connected) {
      if (_joinedClassId != null && _joinedClassId != classId) {
        _socket!.emit('classChat:leave', {'classId': _joinedClassId});
      }
      _emitJoin(classId);
    } else {
      _joinedClassId = classId;
    }
  }

  void _attachSocket(io.Socket socket) {
    _socket = socket;

    _socket!.onConnect((_) {
      final joinId = _joinedClassId;
      if (joinId != null && joinId.isNotEmpty) _emitJoin(joinId);
    });

    _socket!.on('classChat:newMessage', (data) {
      try {
        final map = _asMessageMap(data);
        if (map == null) return;
        final msg = ClassChatMessageEntity.fromJson(map);
        if (msg.id.isEmpty || msg.text.isEmpty) return;
        if (!_controller.isClosed) _controller.add(msg);
      } catch (_) {}
    });

    _socket!.on('classChat:notify', (data) {
      try {
        final map = _asMessageMap(data);
        if (map == null) return;
        final msg = ClassChatMessageEntity.fromJson(map);
        if (msg.id.isEmpty || msg.text.isEmpty) return;
        final className = (map['className'] ?? '').toString().trim();
        if (!_inAppNotifyController.isClosed) {
          _inAppNotifyController.add(
            ClassChatInAppNotifyEvent(message: msg, className: className),
          );
        }
      } catch (_) {}
    });

    _socket!.on('classChat:messageDeleted', (data) {
      try {
        final map = _asMessageMap(data);
        if (map == null) return;
        final id = (map['id'] ?? map['messageId'] ?? '').toString();
        final cid = (map['classId'] ?? '').toString();
        if (id.isEmpty) return;
        if (!_deletedController.isClosed) {
          _deletedController.add((classId: cid, id: id));
        }
      } catch (_) {}
    });
  }

  void _emitJoin(String classId) {
    _joinedClassId = classId;
    _socket?.emit('classChat:join', {'classId': classId});
  }

  /// Normalizes Socket.IO payloads into a message map.
  Map<String, dynamic>? _asMessageMap(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = map['data'];
      if (nested is Map &&
          (map['text'] == null &&
              map['senderName'] == null &&
              map['id'] == null)) {
        return Map<String, dynamic>.from(nested);
      }
      return map;
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  Future<void> leave(String classId) async {
    if (_socket != null && classId.isNotEmpty) {
      _socket!.emit('classChat:leave', {'classId': classId});
    }
    if (_joinedClassId == classId) _joinedClassId = null;
  }

  Future<void> disconnect() async {
    if (_joinedClassId != null) {
      _socket?.emit('classChat:leave', {'classId': _joinedClassId});
      _joinedClassId = null;
    }
    _socket?.dispose();
    _socket = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
    await _inAppNotifyController.close();
    await _deletedController.close();
  }
}

class ClassChatInAppNotifyEvent {
  const ClassChatInAppNotifyEvent({
    required this.message,
    required this.className,
  });

  final ClassChatMessageEntity message;
  final String className;
}
