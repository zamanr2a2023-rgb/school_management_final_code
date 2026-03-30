import 'dart:convert';

import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/teacher_live_sessions_overview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GET /sessions/teacher — teacher live sessions (active, upcoming, completed).
class TeacherLiveSessionsRemoteDatasource {
  TeacherLiveSessionsRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<TeacherLiveSessionsOverview?> fetchOverview() async {
    if (!isConfigured) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('$_apiBase/sessions/teacher');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) return null;

    try {
      var rawBody = response.body;
      if (rawBody.isNotEmpty && rawBody.codeUnitAt(0) == 0xFEFF) {
        rawBody = rawBody.substring(1);
      }
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      return _parseOverview(decoded);
    } on UnauthorizedApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  TeacherLiveSessionsOverview? _parseOverview(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    dynamic data = decoded['data'];

    // Some gateways double-encode `data` as a JSON string.
    if (data is String && data.trim().isNotEmpty) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return null;
      }
    }

    // Doc shape: `data` is a flat session array; partition by `status`.
    if (data is List) {
      return _overviewFromFlatSessionList(data);
    }

    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);

    // Nested buckets (activeNow may be `{ sessions: [] }` or a raw session list).
    dynamic activeBucket = m['activeNow'] ??
        m['active_now'] ??
        m['ongoing'] ??
        m['activeSessions'];
    var upcoming = _parseBucket(m['upcoming'], isActive: false);
    var completed = _parseBucket(m['completed'], isActive: false);
    var activeNow = _parseBucket(activeBucket, isActive: true);

    // Ongoing rows sometimes appear only under upcoming/completed; promote by `status`.
    final ongoingMisplaced = _ongoingFromMaps([
      _sessionListFromBucket(m['upcoming']),
      _sessionListFromBucket(m['completed']),
      m['sessions'],
      m['items'],
      m['currentSessions'],
      m['liveSessions'],
    ]);
    activeNow = _dedupeSessionsById([...activeNow, ...ongoingMisplaced]);

    final activeIds = activeNow.map((s) => s.id).toSet();
    upcoming = upcoming.where((s) => !activeIds.contains(s.id)).toList();
    completed = completed.where((s) => !activeIds.contains(s.id)).toList();

    return TeacherLiveSessionsOverview(
      activeNow: activeNow,
      upcoming: upcoming,
      completed: completed,
      fromRemote: true,
    );
  }

  /// When `GET /sessions/teacher` returns `data: [ { status, ... }, ... ]`.
  TeacherLiveSessionsOverview _overviewFromFlatSessionList(List<dynamic> list) {
    final activeNow = <LiveSessionEntity>[];
    final upcoming = <LiveSessionEntity>[];
    final completed = <LiveSessionEntity>[];
    for (final e in list) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final st = (map['status'] ?? '').toString().toLowerCase().trim();
      final isOngoing =
          st == 'ongoing' || st == 'active' || st == 'live' || st == 'started';
      final entity = _itemToEntity(map, isActive: isOngoing);
      if (entity == null) continue;
      if (isOngoing) {
        activeNow.add(entity);
      } else if (st == 'completed' || st == 'ended' || st == 'cancelled') {
        completed.add(entity);
      } else {
        upcoming.add(entity);
      }
    }
    return TeacherLiveSessionsOverview(
      activeNow: activeNow,
      upcoming: upcoming,
      completed: completed,
      fromRemote: true,
    );
  }

  /// Normalizes a bucket to the raw session list, or null if none.
  List<dynamic>? _sessionListFromBucket(dynamic bucket) {
    if (bucket == null) return null;
    if (bucket is List) return bucket;
    if (bucket is Map) {
      final b = Map<String, dynamic>.from(bucket);
      final sessions = b['sessions'] ?? b['data'] ?? b['items'];
      return sessions is List ? sessions : null;
    }
    return null;
  }

  List<LiveSessionEntity> _dedupeSessionsById(List<LiveSessionEntity> list) {
    final seen = <String>{};
    return list.where((s) => seen.add(s.id)).toList();
  }

  List<LiveSessionEntity> _ongoingFromMaps(List<dynamic> candidates) {
    final out = <LiveSessionEntity>[];
    for (final raw in candidates) {
      if (raw is! List) continue;
      for (final e in raw) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        final st = (map['status'] ?? '').toString().toLowerCase().trim();
        final isOngoing =
            st == 'ongoing' || st == 'active' || st == 'live' || st == 'started';
        if (!isOngoing) continue;
        final entity = _itemToEntity(map, isActive: true);
        if (entity != null) out.add(entity);
      }
    }
    return out;
  }

  List<LiveSessionEntity> _parseBucket(dynamic bucket, {required bool isActive}) {
    if (bucket == null) return [];

    // Some APIs return the bucket as a bare session array.
    if (bucket is List) {
      return _entitiesFromSessionList(bucket, isActive: isActive);
    }

    if (bucket is! Map) return [];
    final b = Map<String, dynamic>.from(bucket);

    dynamic sessions = b['sessions'] ?? b['data'] ?? b['items'];
    if (sessions == null && b['session'] is Map) {
      sessions = [b['session']];
    }
    if (sessions is! List) return [];
    return _entitiesFromSessionList(sessions, isActive: isActive);
  }

  List<LiveSessionEntity> _entitiesFromSessionList(
    List<dynamic> sessions, {
    required bool isActive,
  }) {
    final out = <LiveSessionEntity>[];
    for (final e in sessions) {
      if (e == null) continue;
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final entity = _itemToEntity(map, isActive: isActive);
      if (entity != null) out.add(entity);
    }
    return out;
  }

  static String? _readDocumentId(Map<String, dynamic> m) {
    dynamic raw = m['_id'] ?? m['id'];
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : s;
    }
    if (raw is int || raw is double) return raw.toString();
    if (raw is Map) {
      final oid = raw[r'$oid'] ?? raw['\$oid'] ?? raw['oid'];
      if (oid != null) {
        final s = oid.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static LiveSessionEntity? _itemToEntity(Map<String, dynamic> m, {required bool isActive}) {
    final id = _readDocumentId(m);
    if (id == null || id.isEmpty) return null;

    final title = m['title']?.toString() ?? '';
    final dateRaw = m['date']?.toString() ?? '';
    final time = m['time']?.toString() ?? '';
    final link = m['zoomLink']?.toString() ?? m['meetingLink']?.toString() ?? '';
    final isZoom = link.toLowerCase().contains('zoom');
    final classId = m['classId']?.toString() ?? '';
    final className = m['className']?.toString();
    final grade = m['grade']?.toString();
    final subject = m['subject']?.toString();
    final dur = m['duration'];
    final durationMinutes = dur is int ? dur : int.tryParse(dur?.toString() ?? '');

    return LiveSessionEntity(
      id: id,
      classId: classId,
      title: title,
      date: dateRaw.isNotEmpty ? dateRaw : '',
      time: time,
      platform: isZoom ? LiveSessionPlatform.zoom : LiveSessionPlatform.meet,
      link: link,
      isActive: isActive,
      className: (className != null && className.isNotEmpty) ? className : null,
      gradeLevel: (grade != null && grade.isNotEmpty) ? grade : null,
      subject: (subject != null && subject.isNotEmpty) ? subject : null,
      durationMinutes: durationMinutes,
    );
  }

  /// POST /sessions — create live session (pending admin approval).
  Future<CreateLiveSessionResult> createSession({
    required String title,
    required String gradeId,
    required String subjectId,
    required String classId,
    required String className,
    required String date,
    required String time,
    required int duration,
    required String zoomLink,
  }) async {
    if (!isConfigured) {
      return const CreateLiveSessionResult(success: false, message: 'API not configured');
    }
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) {
      return const CreateLiveSessionResult(success: false, message: 'Not signed in');
    }

    final uri = Uri.parse('$_apiBase/sessions');
    final body = <String, dynamic>{
      'title': title.trim(),
      'gradeId': gradeId.trim(),
      'subjectId': subjectId.trim(),
      'classId': classId.trim(),
      'className': className.trim(),
      'date': date.trim(),
      'time': time.trim(),
      'duration': duration,
      'zoomLink': zoomLink.trim(),
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      Map<String, dynamic>? decoded;
      final rawBody = response.body.trim();
      if (rawBody.isNotEmpty) {
        try {
          final raw = jsonDecode(response.body);
          if (raw is Map<String, dynamic>) {
            decoded = raw;
          } else if (raw is Map) {
            decoded = Map<String, dynamic>.from(raw);
          }
        } catch (_) {
          decoded = null;
        }
      }
      if (decoded != null) ensureAuthorized(decoded);

      final code = response.statusCode;
      if (code == 200 || code == 201) {
        if (decoded == null) {
          return const CreateLiveSessionResult(
            success: true,
            message: 'Session created.',
          );
        }
        final s = decoded['success'];
        final hasData = decoded['data'] != null;
        final ok = s == true ||
            s == 1 ||
            (s is String && s.toLowerCase() == 'true') ||
            (s == null && hasData);
        final msg = decoded['message']?.toString();
        return CreateLiveSessionResult(success: ok, message: msg);
      }
      final failMsg = decoded?['message']?.toString() ??
          (rawBody.isNotEmpty ? rawBody : 'Request failed ($code)');
      return CreateLiveSessionResult(success: false, message: failMsg);
    } on UnauthorizedApiException {
      return const CreateLiveSessionResult(success: false, message: 'Unauthorized');
    } catch (e) {
      return CreateLiveSessionResult(success: false, message: e.toString());
    }
  }
}
