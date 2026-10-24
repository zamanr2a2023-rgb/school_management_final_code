import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/class_chat_message_entity.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClassChatRemoteDatasource {
  ClassChatRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  String? get _token => _prefs.getString(AppConstants.sessionTokenKey);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Future<ClassChatRoomEntity?> getRoom(String classId) async {
    if (!isConfigured || classId.isEmpty || _token == null || _token!.isEmpty) {
      return null;
    }
    final uri = Uri.parse('$_apiBase/chat/classes/$classId');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      _throwIfForbidden(response);
      return null;
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      final data = decoded?['data'];
      if (data is! Map<String, dynamic>) return null;
      return ClassChatRoomEntity.fromJson(data);
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<ClassChatMessagesPage> getMessages(
    String classId, {
    int limit = 50,
    String? before,
  }) async {
    if (!isConfigured || classId.isEmpty || _token == null || _token!.isEmpty) {
      return const ClassChatMessagesPage(messages: [], hasMore: false);
    }
    final params = <String, String>{'limit': '$limit'};
    if (before != null && before.isNotEmpty) params['before'] = before;
    final uri = Uri.parse('$_apiBase/chat/classes/$classId/messages')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 403 || response.statusCode == 404) {
      throw ClassChatAccessException(
        _extractMessage(response) ?? 'Access denied',
      );
    }
    if (response.statusCode != 200) {
      return const ClassChatMessagesPage(messages: [], hasMore: false);
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      final data = decoded?['data'];
      final meta = decoded?['meta'];
      final list = <ClassChatMessageEntity>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            list.add(ClassChatMessageEntity.fromJson(item));
          }
        }
      }
      final hasMore = meta is Map && meta['hasMore'] == true;
      final nextBefore = meta is Map ? meta['nextBefore']?.toString() : null;
      return ClassChatMessagesPage(
        messages: list,
        hasMore: hasMore,
        nextBefore: nextBefore,
      );
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      return const ClassChatMessagesPage(messages: [], hasMore: false);
    }
  }

  Future<ClassChatMessageEntity?> sendMessage(String classId, String text) async {
    if (!isConfigured || classId.isEmpty || _token == null || _token!.isEmpty) {
      return null;
    }
    final uri = Uri.parse('$_apiBase/chat/classes/$classId/messages');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode == 403 || response.statusCode == 404) {
      throw ClassChatAccessException(
        _extractMessage(response) ?? 'Access denied',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ClassChatApiException(
        _extractMessage(response) ?? 'Failed to send message',
      );
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      final data = decoded?['data'];
      if (data is! Map<String, dynamic>) return null;
      return ClassChatMessageEntity.fromJson(data);
    } on UnauthorizedApiException {
      rethrow;
    }
  }

  Future<void> deleteMessage(String classId, String messageId) async {
    if (!isConfigured ||
        classId.isEmpty ||
        messageId.isEmpty ||
        _token == null ||
        _token!.isEmpty) {
      throw ClassChatApiException('Not configured');
    }
    final uri =
        Uri.parse('$_apiBase/chat/classes/$classId/messages/$messageId');
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode == 403 || response.statusCode == 404) {
      throw ClassChatAccessException(
        _extractMessage(response) ?? 'Access denied',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ClassChatApiException(
        _extractMessage(response) ?? 'Failed to delete message',
      );
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      // empty / non-json body on 204 is fine
    }
  }

  String _localReadKey(String classId) => 'class_chat_last_read_$classId';

  /// Works even when the server unread API is not deployed yet (local fallback).
  Future<int> getUnreadCount(String classId) async {
    if (!isConfigured || classId.isEmpty || _token == null || _token!.isEmpty) {
      return 0;
    }

    // Prefer server unread count when available.
    try {
      final uri = Uri.parse('$_apiBase/chat/classes/$classId/unread');
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        ensureAuthorized(decoded);
        final data = decoded?['data'];
        if (data is Map && data.containsKey('unreadCount')) {
          return int.tryParse('${data['unreadCount'] ?? 0}') ?? 0;
        }
      }
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      // Fall through to local count.
    }

    return _localUnreadCount(classId);
  }

  Future<int> _localUnreadCount(String classId) async {
    final myId = _prefs.getString(AppConstants.sessionUserIdKey) ?? '';
    final lastReadMs = _prefs.getInt(_localReadKey(classId));
    final lastRead = lastReadMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastReadMs, isUtc: true);

    final page = await getMessages(classId, limit: 50);
    var count = 0;
    for (final m in page.messages) {
      if (myId.isNotEmpty && m.senderId == myId) continue;
      if (lastRead != null && !m.createdAt.toUtc().isAfter(lastRead)) {
        continue;
      }
      count++;
    }
    return count;
  }

  Future<void> markAsRead(String classId) async {
    if (classId.isEmpty) return;

    // Always persist locally so badges clear even if server lacks /read.
    await _prefs.setInt(
      _localReadKey(classId),
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    if (!isConfigured || _token == null || _token!.isEmpty) return;

    try {
      final uri = Uri.parse('$_apiBase/chat/classes/$classId/read');
      final response = await http.put(uri, headers: _headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        ensureAuthorized(decoded);
      }
      // 404/501 etc. = endpoint not on this host yet; local read is enough.
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      // ignore network / parse errors
    }
  }

  Future<bool> getMuted(String classId) async {
    if (!isConfigured || classId.isEmpty || _token == null || _token!.isEmpty) {
      return false;
    }
    final uri = Uri.parse('$_apiBase/chat/classes/$classId/mute');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return false;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      final data = decoded?['data'];
      if (data is Map) return data['muted'] == true;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setMuted(String classId, bool muted) async {
    if (!isConfigured || classId.isEmpty || _token == null || _token!.isEmpty) {
      throw ClassChatApiException('Not configured');
    }
    final uri = Uri.parse('$_apiBase/chat/classes/$classId/mute');
    final response = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode({'muted': muted}),
    );
    if (response.statusCode == 403 || response.statusCode == 404) {
      throw ClassChatAccessException(
        _extractMessage(response) ?? 'Access denied',
      );
    }
    if (response.statusCode != 200) {
      throw ClassChatApiException(
        _extractMessage(response) ?? 'Failed to update mute',
      );
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      final data = decoded?['data'];
      if (data is Map) return data['muted'] == true;
      return muted;
    } on UnauthorizedApiException {
      rethrow;
    }
  }

  Future<void> registerFcmToken(String token) async {
    if (!isConfigured ||
        token.isEmpty ||
        _token == null ||
        _token!.isEmpty) {
      return;
    }
    final uri = Uri.parse('$_apiBase/users/me/fcm-token');
    await http.put(
      uri,
      headers: _headers,
      body: jsonEncode({'token': token}),
    );
  }

  Future<void> unregisterFcmToken(String token) async {
    if (!isConfigured ||
        token.isEmpty ||
        _token == null ||
        _token!.isEmpty) {
      return;
    }
    final uri = Uri.parse('$_apiBase/users/me/fcm-token');
    await http.delete(
      uri,
      headers: _headers,
      body: jsonEncode({'token': token}),
    );
  }

  void _throwIfForbidden(http.Response response) {
    if (response.statusCode == 403 || response.statusCode == 404) {
      throw ClassChatAccessException(
        _extractMessage(response) ?? 'Access denied',
      );
    }
  }

  String? _extractMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      return decoded?['message']?.toString();
    } catch (_) {
      return null;
    }
  }
}

class ClassChatAccessException implements Exception {
  ClassChatAccessException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ClassChatApiException implements Exception {
  ClassChatApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
