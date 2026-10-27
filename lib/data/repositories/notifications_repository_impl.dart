import 'dart:convert';

import 'package:high_school/core/utils/app_date_format.dart';
import 'package:high_school/data/datasources/notifications_remote_datasource.dart';
import 'package:high_school/domain/entities/notification_entity.dart';
import 'package:high_school/domain/repositories/notifications_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._prefs)
      : _remote = NotificationsRemoteDatasource(_prefs);

  static const _localInboxKey = 'notifications_local_chat_inbox_v1';

  final SharedPreferences _prefs;
  final NotificationsRemoteDatasource _remote;

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    final remote = await _fetchRemoteEntities();
    final local = _readLocalInbox();
    final merged = [...remote, ...local];
    merged.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return merged;
  }

  @override
  Future<void> markAsRead(String id) async {
    if (id.startsWith('chat_')) {
      await _markLocalRead(id);
      return;
    }
    await _remote.markReadOnServer(id);
    await _markLocalRead(id);
  }

  @override
  Future<void> markAllAsRead() async {
    final all = await getNotifications();
    for (final n in all) {
      if (!n.read) {
        await markAsRead(n.id);
      }
    }
  }

  @override
  Future<void> recordClassChatNotification({
    required String classId,
    required String title,
    required String body,
    required String messageId,
  }) async {
    if (classId.isEmpty || messageId.isEmpty) return;

    final id = 'chat_${classId}_$messageId';
    final inbox = _readLocalRaw();
    if (inbox.any((e) => e['id'] == id)) return;

    final now = DateTime.now().toUtc();
    inbox.insert(0, {
      'id': id,
      'classId': classId,
      'from': title.isNotEmpty ? title : 'Class Chat',
      'message': body,
      'createdAt': now.toIso8601String(),
      'read': false,
    });
    // Keep inbox bounded.
    if (inbox.length > 100) {
      inbox.removeRange(100, inbox.length);
    }
    await _prefs.setString(_localInboxKey, jsonEncode(inbox));
  }

  Future<List<NotificationEntity>> _fetchRemoteEntities() async {
    try {
      final rows = await _remote.fetchMyNotifications();
      return rows.map(_mapRemoteRow).whereType<NotificationEntity>().toList();
    } catch (_) {
      return [];
    }
  }

  NotificationEntity? _mapRemoteRow(Map<String, dynamic> row) {
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty) return null;

    final channel = (row['channel'] ?? 'announcement').toString().toLowerCase();
    final type = switch (channel) {
      'announcement' => NotificationType.admin,
      'automated' => NotificationType.system,
      _ => NotificationType.system,
    };

    final title = (row['title'] ?? '').toString().trim();
    final message = (row['message'] ?? '').toString().trim();
    final created = row['sentAt'] ?? row['createdAt'];
    final read = row['isRead'] == true || row['readAt'] != null;

    return NotificationEntity(
      id: id,
      type: type,
      from: title.isNotEmpty ? title : 'School',
      message: message,
      timestamp: AppDateFormat.dateTime(created),
      read: read,
      sortKey: _parseSortKey(created),
    );
  }

  List<NotificationEntity> _readLocalInbox() {
    return _readLocalRaw().map(_mapLocalRow).whereType<NotificationEntity>().toList();
  }

  NotificationEntity? _mapLocalRow(Map<String, dynamic> row) {
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty) return null;
    return NotificationEntity(
      id: id,
      type: NotificationType.chat,
      from: (row['from'] ?? 'Class Chat').toString(),
      message: (row['message'] ?? '').toString(),
      timestamp: AppDateFormat.dateTime(row['createdAt']),
      read: row['read'] == true,
      sortKey: _parseSortKey(row['createdAt']),
    );
  }

  List<Map<String, dynamic>> _readLocalRaw() {
    final raw = _prefs.getString(_localInboxKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _markLocalRead(String id) async {
    final inbox = _readLocalRaw();
    var changed = false;
    for (var i = 0; i < inbox.length; i++) {
      if (inbox[i]['id'] == id && inbox[i]['read'] != true) {
        inbox[i] = {...inbox[i], 'read': true};
        changed = true;
      }
    }
    if (changed) {
      await _prefs.setString(_localInboxKey, jsonEncode(inbox));
    }
  }

  DateTime _parseSortKey(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
