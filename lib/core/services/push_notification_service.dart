import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:high_school/data/datasources/class_chat_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles FCM + local notifications for class chat.
/// Soft-fails when Firebase is not configured (no google-services.json / options).
class PushNotificationService {
  PushNotificationService(this._prefs, this._chatRemote);

  // Reserved for future local mute cache / routing prefs.
  // ignore: unused_field
  final SharedPreferences _prefs;
  final ClassChatRemoteDatasource _chatRemote;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  String? _token;
  void Function(String classId)? onOpenClassChat;

  static const _androidChannel = AndroidNotificationChannel(
    'class_chat',
    'Class Chat',
    description: 'Notifications for new class chat messages',
    importance: Importance.high,
  );

  String? get token => _token;
  bool get isReady => _ready;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[push] Firebase.initializeApp failed (optional): $e');
      return;
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final map = jsonDecode(payload) as Map<String, dynamic>;
            final classId = map['classId']?.toString() ?? '';
            if (classId.isNotEmpty) onOpenClassChat?.call(classId);
          } catch (_) {}
        },
      );

      if (Platform.isAndroid) {
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_androidChannel);
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteOpen);

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _handleRemoteOpen(initial);
      }

      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((t) async {
        _token = t;
        await _chatRemote.registerFcmToken(t);
      });

      // ignore: deprecated_member_use
      _token = await messaging.getToken();
      _ready = true;
      if (_token != null && _token!.isNotEmpty) {
        await _chatRemote.registerFcmToken(_token!);
      }
    } catch (e) {
      debugPrint('[push] init failed (optional): $e');
      _ready = false;
    }
  }

  /// Call after login / session restore when API token is available.
  Future<void> syncTokenWithBackend() async {
    if (!_ready) return;
    try {
      // ignore: deprecated_member_use
      _token ??= await FirebaseMessaging.instance.getToken();
      if (_token != null && _token!.isNotEmpty) {
        await _chatRemote.registerFcmToken(_token!);
      }
    } catch (e) {
      debugPrint('[push] syncToken failed: $e');
    }
  }

  Future<void> clearTokenOnLogout() async {
    final t = _token;
    if (t != null && t.isNotEmpty) {
      try {
        await _chatRemote.unregisterFcmToken(t);
      } catch (_) {}
    }
    try {
      if (_ready) {
        // ignore: deprecated_member_use
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {}
    _token = null;
  }

  void _handleRemoteOpen(RemoteMessage message) {
    final classId = message.data['classId']?.toString() ?? '';
    if (classId.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        onOpenClassChat?.call(classId);
      });
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Class Chat';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';
    final classId = message.data['classId']?.toString() ?? '';
    final payload = jsonEncode({
      'type': message.data['type'] ?? 'class_chat',
      'classId': classId,
      'messageId': message.data['messageId']?.toString() ?? '',
    });

    await _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}

/// Top-level background handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}
