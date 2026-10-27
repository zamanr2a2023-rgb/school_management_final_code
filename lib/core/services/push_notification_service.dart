import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:high_school/data/datasources/class_chat_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles FCM + local / in-app notifications for class chat (with sound).
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

  /// Class chat currently open — skip banner for that room (sound still optional).
  String? activeClassChatId;

  // Channel id bumped when sound settings change (Android freezes channel config).
  static const _androidChannel = AndroidNotificationChannel(
    'class_chat_v2',
    'Class Chat',
    description: 'Notifications for new class chat messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  String? get token => _token;
  bool get isReady => _ready;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[push] Firebase.initializeApp failed (optional): $e');
      // Still init local notifications for in-app alerts without FCM.
      await _initLocalOnly();
      return;
    }

    try {
      await _initLocalOnly();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
      );

      await messaging.setForegroundNotificationPresentationOptions(
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

  Future<void> _initLocalOnly() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
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

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(_androidChannel);
    }

    if (!kIsWeb && Platform.isIOS) {
      final iosPlugin = _local.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[push] iOS notification permissions granted: $granted');
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

  /// Play alert sound + haptic (e.g. when user unmutes notifications).
  Future<void> playChatSound() async {
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('[push] playChatSound failed: $e');
    }
  }

  /// In-app heads-up notification + sound for a new class chat message.
  Future<void> notifyClassChatMessage({
    required String classId,
    required String title,
    required String body,
    String? messageId,
    bool playSoundOnly = false,
  }) async {
    if (classId.isEmpty) return;

    final viewingThisChat =
        activeClassChatId != null && activeClassChatId == classId;
    if (viewingThisChat) return;

    await HapticFeedback.mediumImpact();
    await _showLocal(
      title: title,
      body: body,
      classId: classId,
      messageId: messageId ?? '',
      timeoutAfterMs: playSoundOnly ? 2500 : null,
    );
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
    final classId = message.data['classId']?.toString() ?? '';
    // Socket path already notifies while this chat is open — avoid double alert.
    if (classId.isNotEmpty && activeClassChatId == classId) {
      return;
    }

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Class Chat';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';

    await notifyClassChatMessage(
      classId: classId,
      title: title,
      body: body,
      messageId: message.data['messageId']?.toString(),
    );
  }

  Future<void> _showLocal({
    required String title,
    required String body,
    required String classId,
    String messageId = '',
    String type = 'class_chat',
    int? timeoutAfterMs,
  }) async {
    final payload = jsonEncode({
      'type': type,
      'classId': classId,
      'messageId': messageId,
    });

    try {
      await _local.show(
        id: Object.hash(classId, messageId, title, body) & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            category: AndroidNotificationCategory.message,
            timeoutAfter: timeoutAfterMs,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[push] show local failed: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}

/// Top-level background handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}
