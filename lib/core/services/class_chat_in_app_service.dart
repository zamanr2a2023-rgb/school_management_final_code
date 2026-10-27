import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:high_school/core/services/push_notification_service.dart';
import 'package:high_school/data/datasources/class_chat_socket_client.dart';
import 'package:high_school/domain/repositories/notifications_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';

/// Listens for `classChat:notify` on the user socket room and shows
/// foreground local notifications + sound while the app is open.
class ClassChatInAppService {
  ClassChatInAppService(
    this._socket,
    this._push,
    this._auth,
    this._notifications,
  );

  final ClassChatSocketClient _socket;
  final PushNotificationService _push;
  final AuthProvider _auth;
  final NotificationsRepository _notifications;

  StreamSubscription<ClassChatInAppNotifyEvent>? _notifySub;
  final Set<String> _recentMessageKeys = {};
  static const _dedupeWindow = Duration(seconds: 8);

  void start() {
    _auth.addListener(_syncWithSession);
    _syncWithSession();
  }

  void dispose() {
    _auth.removeListener(_syncWithSession);
    unawaited(_notifySub?.cancel());
    _notifySub = null;
  }

  Future<void> _syncWithSession() async {
    await _notifySub?.cancel();
    _notifySub = null;

    if (!_auth.isAuthenticated) {
      await _socket.disconnect();
      return;
    }

    try {
      await _socket.ensureConnected();
      _notifySub = _socket.inAppNotifications.listen(_onNotify);
    } catch (e) {
      debugPrint('[classChatInApp] connect failed: $e');
    }
  }

  Future<void> _onNotify(ClassChatInAppNotifyEvent event) async {
    final msg = event.message;
    final myId = _auth.user?.id ?? '';
    if (myId.isNotEmpty && msg.senderId == myId) return;

    final dedupeKey = '${msg.classId}:${msg.id}';
    if (_recentMessageKeys.contains(dedupeKey)) return;
    _recentMessageKeys.add(dedupeKey);
    Future.delayed(_dedupeWindow, () => _recentMessageKeys.remove(dedupeKey));

    final title = event.className.isNotEmpty
        ? event.className
        : (msg.classId.isNotEmpty ? 'Class Chat' : 'New message');
    final body = '${msg.senderName}: ${msg.text}';

    await _notifications.recordClassChatNotification(
      classId: msg.classId,
      title: title,
      body: body,
      messageId: msg.id,
    );

    await _push.notifyClassChatMessage(
      classId: msg.classId,
      title: title,
      body: body,
      messageId: msg.id,
    );
  }
}
