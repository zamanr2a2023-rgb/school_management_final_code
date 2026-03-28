import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/student_entity.dart';
import 'package:high_school/domain/entities/teacher_class_detail_result.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Remote datasource for GET /classes/my (Teacher) and GET /classes/:classId (Teacher, Admin).
class TeacherClassesRemoteDatasource {
  TeacherClassesRemoteDatasource(this._prefs)
      : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase {
    final b = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return '$b/api/v1';
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<List<ClassEntity>> getMyClasses() async {
    if (!isConfigured) return [];
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return [];

    final uri = Uri.parse('$_apiBase/classes/my');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) return [];
    try {
      return _parseList(response.body);
    } on UnauthorizedApiException {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _fetchClassDataMap(String classId) async {
    if (!isConfigured || classId.isEmpty) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('$_apiBase/classes/$classId');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) return null;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      if (decoded == null) return null;
      final data = decoded['data'];
      if (data == null) return null;
      return data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
    } on UnauthorizedApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ClassEntity?> getClassById(String classId) async {
    final map = await _fetchClassDataMap(classId);
    return map == null ? null : _itemToEntity(map);
  }

  /// GET /classes/:classId — full nested payload for teacher class details UI.
  Future<TeacherClassDetailResult?> getClassDetailById(String classId) async {
    final map = await _fetchClassDataMap(classId);
    if (map == null) return null;
    final cls = _itemToEntity(map);
    if (cls == null) return null;
    final lessons = _parseLessonDetails(map['lessonDetails'], classId);
    final assignments = _parseAssignmentDetails(map['assignmentDetails'], classId);
    final students = _parseStudents(map['students']);
    final liveSessions = _parseLiveSessions(map['liveSessionDetails'], classId);
    final analytics = _parseAnalytics(map['analytics']);
    return TeacherClassDetailResult(
      classEntity: cls,
      lessons: lessons,
      assignments: assignments,
      students: students,
      liveSessions: liveSessions,
      analytics: analytics,
    );
  }

  String _resolveAssetUrl(String path) {
    final p = path.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    try {
      final base = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
      return Uri.parse('$base/').resolve(p.startsWith('/') ? p.substring(1) : p).toString();
    } catch (_) {
      return p;
    }
  }

  List<StudentEntity> _parseStudents(dynamic raw) {
    if (raw is! List) return [];
    final out = <StudentEntity>[];
    for (final e in raw) {
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final id = m['id']?.toString() ?? m['_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final name = m['name']?.toString() ?? '';
      final phone = m['phone']?.toString() ?? '';
      final progress = m['overallProgress'];
      final grade = progress is int ? progress : int.tryParse(progress?.toString() ?? '') ?? 0;
      final img = m['profileImage']?.toString();
      final avatar = (img == null || img.isEmpty) ? null : _resolveAssetUrl(img);
      out.add(StudentEntity(id: id, name: name, email: phone, grade: grade, avatar: avatar));
    }
    return out;
  }

  List<LiveSessionEntity> _parseLiveSessions(dynamic raw, String classId) {
    if (raw is! List) return [];
    final out = <LiveSessionEntity>[];
    for (final e in raw) {
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final id = m['id']?.toString() ?? m['_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final title = m['title']?.toString() ?? 'Session';
      final dateRaw = m['date']?.toString() ?? '';
      var dateStr = dateRaw;
      if (dateRaw.length >= 10) dateStr = dateRaw.substring(0, 10);
      final time = m['time']?.toString() ?? '';
      final link = m['zoomLink']?.toString() ?? m['link']?.toString() ?? '';
      final statusStr = (m['status']?.toString() ?? '').toLowerCase();
      final isActive = statusStr == 'live' || statusStr == 'ongoing' || statusStr == 'active';
      final platform = link.toLowerCase().contains('zoom') ? LiveSessionPlatform.zoom : LiveSessionPlatform.meet;
      var cid = m['classId']?.toString() ?? '';
      if (cid.isEmpty) cid = classId;
      final cn = m['className']?.toString();
      out.add(LiveSessionEntity(
        id: id,
        classId: cid,
        title: title,
        date: dateStr,
        time: time,
        platform: platform,
        link: link,
        isActive: isActive,
        className: (cn == null || cn.isEmpty) ? null : cn,
      ));
    }
    return out;
  }

  TeacherClassAnalytics? _parseAnalytics(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    double toD(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    int toI(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return TeacherClassAnalytics(
      avgGrade: toD(m['avgGrade']),
      avgAttendance: toD(m['avgAttendance']),
      totalStudents: toI(m['totalStudents']),
      totalLessons: toI(m['totalLessons']),
      totalAssignments: toI(m['totalAssignments']),
      totalLiveSessions: toI(m['totalLiveSessions']),
    );
  }

  List<LessonEntity> _parseLessonDetails(dynamic raw, String fallbackClassId) {
    if (raw is! List) return [];
    final out = <LessonEntity>[];
    for (final e in raw) {
      final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final lesson = _lessonFromJson(map, fallbackClassId);
      if (lesson != null) out.add(lesson);
    }
    return out;
  }

  LessonEntity? _lessonFromJson(Map<String, dynamic> m, String fallbackClassId) {
    final id = m['_id']?.toString() ?? m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    var classId = m['classId']?.toString() ?? '';
    if (classId.isEmpty) classId = fallbackClassId;
    final title = m['title']?.toString() ?? '';
    final description = m['description']?.toString() ?? '';
    final ct = (m['contentType'] ?? m['type'])?.toString().toLowerCase() ?? 'text';
    LessonType type = LessonType.text;
    if (ct.contains('video')) {
      type = LessonType.video;
    } else if (ct.contains('pdf')) {
      type = LessonType.pdf;
    }
    var content = m['content']?.toString() ?? '';
    if (content.isEmpty) {
      content = m['videoUrl']?.toString() ?? m['video']?.toString() ?? '';
    }
    if (content.isEmpty && m['files'] is List && (m['files'] as List).isNotEmpty) {
      final f = (m['files'] as List).first;
      if (f is Map) {
        content = f['url']?.toString() ?? f['path']?.toString() ?? '';
      }
    }
    if (content.isNotEmpty && !content.startsWith('http://') && !content.startsWith('https://')) {
      content = _resolveAssetUrl(content);
    }
    var dateStr = m['date']?.toString() ?? '';
    if (dateStr.isEmpty) {
      final created = m['createdAt']?.toString();
      if (created != null && created.length >= 10) dateStr = created.substring(0, 10);
    }
    final duration = m['duration']?.toString();
    final statusStr = (m['status']?.toString() ?? 'published').toLowerCase();
    final status = statusStr == 'draft' ? LessonStatus.draft : LessonStatus.published;
    var lastUpdated = m['updatedAt']?.toString() ?? m['lastUpdated']?.toString() ?? m['createdAt']?.toString() ?? '';
    if (lastUpdated.length >= 10) lastUpdated = lastUpdated.substring(0, 10);
    if (lastUpdated.isEmpty) lastUpdated = dateStr;
    final module = m['chapter']?.toString() ?? m['module']?.toString();
    return LessonEntity(
      id: id,
      classId: classId,
      title: title.isEmpty ? 'Lesson' : title,
      description: description,
      type: type,
      content: content,
      date: dateStr,
      duration: duration,
      status: status,
      lastUpdated: lastUpdated.isEmpty ? dateStr : lastUpdated,
      module: module,
    );
  }

  List<AssignmentEntity> _parseAssignmentDetails(dynamic raw, String fallbackClassId) {
    if (raw is! List) return [];
    final out = <AssignmentEntity>[];
    for (final e in raw) {
      final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final a = _assignmentFromJson(map, fallbackClassId);
      if (a != null) out.add(a);
    }
    return out;
  }

  AssignmentEntity? _assignmentFromJson(Map<String, dynamic> m, String fallbackClassId) {
    final id = m['_id']?.toString() ?? m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    var classId = m['classId']?.toString() ?? '';
    if (classId.isEmpty) classId = fallbackClassId;
    final title = m['title']?.toString() ?? '';
    final description = m['description']?.toString() ?? '';
    var due = m['dueDate']?.toString() ?? '';
    if (due.isEmpty) {
      final dueAt = m['dueAt']?.toString();
      if (dueAt != null && dueAt.length >= 10) {
        due = dueAt.substring(0, 10);
      } else if (dueAt != null) {
        due = dueAt;
      }
    }
    final p = m['points'];
    final points = p is int ? p : int.tryParse(p?.toString() ?? '') ?? 0;
    final statusStr = (m['status']?.toString() ?? 'pending').toLowerCase();
    AssignmentStatus st = AssignmentStatus.pending;
    if (statusStr.contains('grad')) {
      st = AssignmentStatus.graded;
    } else if (statusStr.contains('submit')) {
      st = AssignmentStatus.submitted;
    }
    final g = m['grade'] ?? m['myGrade'];
    final grade = g is int ? g : int.tryParse(g?.toString() ?? '');
    final feedback = m['feedback']?.toString();
    return AssignmentEntity(
      id: id,
      classId: classId,
      title: title.isEmpty ? 'Assignment' : title,
      description: description,
      dueDate: due,
      points: points,
      status: st,
      grade: grade,
      feedback: feedback,
    );
  }

  List<ClassEntity> _parseList(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      if (decoded == null) return [];
      final data = decoded['data'];
      if (data is! List) return [];
      return data
          .map((e) => _itemToEntity(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .whereType<ClassEntity>()
          .toList();
    } on UnauthorizedApiException {
      return [];
    } catch (_) {
      return [];
    }
  }

  static ClassEntity? _itemToEntity(Map<String, dynamic> m) {
    final id = m['_id']?.toString() ?? m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final subject = m['subject']?.toString() ?? '';
    final gradeLevel = m['gradeLevel']?.toString() ?? '';
    final className = m['className']?.toString();
    final name = (className != null && className.isNotEmpty)
        ? className
        : '${subject.isNotEmpty ? subject : 'Class'}${gradeLevel.isNotEmpty ? ' - $gradeLevel' : ''}';
    int students = 0;
    if (m['totalStudents'] != null) {
      if (m['totalStudents'] is int) {
        students = m['totalStudents'] as int;
      } else {
        students = int.tryParse(m['totalStudents'].toString()) ?? 0;
      }
    }
    if (students == 0 && m['students'] != null) {
      if (m['students'] is List) {
        students = (m['students'] as List).length;
      } else if (m['students'] is int) {
        students = m['students'] as int;
      } else {
        students = int.tryParse(m['students'].toString()) ?? 0;
      }
    }
    final schedule = _scheduleToString(m['schedule']);
    String teacher = '';
    String teacherId = '';
    final t = m['teacher'];
    if (t is Map<String, dynamic>) {
      teacher = t['name']?.toString() ?? '';
      teacherId = t['_id']?.toString() ?? t['id']?.toString() ?? '';
    } else if (t != null) {
      teacherId = t.toString();
      teacher = m['teacherName']?.toString() ?? '';
    }
    return ClassEntity(
      id: id,
      name: name,
      subject: subject,
      category: '',
      teacher: teacher,
      teacherId: teacherId,
      students: students,
      color: m['color']?.toString() ?? '',
      schedule: schedule,
      room: m['room']?.toString() ?? '',
      level: gradeLevel,
      schoolYear: m['schoolYear']?.toString() ?? '',
      gradeId: _idString(m['gradeId']),
      subjectId: _idString(m['subjectId']),
    );
  }

  /// API may send `gradeId` / `subjectId` as a string or as `{ _id, label|name }`.
  static String? _idString(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final id = v['_id'] ?? v['id'];
      if (id != null) return id.toString();
      return null;
    }
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Format schedule from API (array of {day, startMin, endMin}) to readable string.
  static String _scheduleToString(dynamic schedule) {
    if (schedule == null) return '';
    if (schedule is String) return schedule;
    if (schedule is! List || schedule.isEmpty) return '';
    const dayNames = {'sun': 'Sun', 'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu', 'fri': 'Fri', 'sat': 'Sat'};
    final parts = <String>[];
    for (final e in schedule) {
      final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final day = (map['day']?.toString() ?? '').toLowerCase();
      final startMin = map['startMin'] is int ? map['startMin'] as int : int.tryParse(map['startMin']?.toString() ?? '') ?? 0;
      final endMin = map['endMin'] is int ? map['endMin'] as int : int.tryParse(map['endMin']?.toString() ?? '') ?? 0;
      final startTime = _minToTimeStr(startMin);
      final endTime = _minToTimeStr(endMin);
      final dayLabel = dayNames[day] ?? day;
      parts.add('$dayLabel $startTime - $endTime');
    }
    return parts.join(', ');
  }

  static String _minToTimeStr(int minFromMidnight) {
    final h = minFromMidnight ~/ 60;
    final m = minFromMidnight % 60;
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hour:${m.toString().padLeft(2, '0')} $ampm';
  }
}
