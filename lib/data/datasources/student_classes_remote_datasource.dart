import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/entities/student_class_detail_result.dart';
import 'package:high_school/domain/entities/student_class_item.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GET /classes/student/my (Student) — student's enrolled classes
class StudentClassesRemoteDatasource {
  StudentClassesRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// GET /classes/student/:classId (Student) — class, [lessonDetails], [assignmentDetails].
  Future<StudentClassDetailResult?> getStudentClassDetail(String classId) async {
    return _fetchStudentClassDetail(classId);
  }

  /// GET /classes/student/:classId (Student) — class only. Same HTTP as [getStudentClassDetail].
  Future<ClassEntity?> getStudentClassById(String classId) async {
    final detail = await _fetchStudentClassDetail(classId);
    return detail?.classEntity;
  }

  Future<StudentClassDetailResult?> _fetchStudentClassDetail(String classId) async {
    if (!isConfigured || classId.isEmpty) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('$_apiBase/classes/student/$classId');
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
      final data = decoded?['data'];
      if (data is! Map<String, dynamic>) return null;
      final cls = _mapStudentClassToEntity(data);
      if (cls == null) return null;
      final lessons = _parseLessonDetails(data['lessonDetails'], cls.id);
      final assignments = _parseAssignmentDetails(data['assignmentDetails'], cls.id);
      return StudentClassDetailResult(
        classEntity: cls,
        lessons: lessons,
        assignments: assignments,
      );
    } on UnauthorizedApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET /classes/student/my (Student) — data: array of { classId, subject, gradeLevel, teacher: { id, name }, studentsCount, maxStudents, status }
  Future<List<StudentClassItem>> getStudentClasses() async {
    if (!isConfigured) return [];
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return [];
    final uri = Uri.parse('$_apiBase/classes/student/my');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) return [];
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      return _parseList(response.body);
    } on UnauthorizedApiException {
      return [];
    }
  }

  List<StudentClassItem> _parseList(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>?;
      if (decoded == null) return [];
      final data = decoded['data'];
      if (data == null) return [];
      final list = data is List ? data : (data is Map ? [data] : null);
      if (list == null) return [];
      return list
          .map((e) => StudentClassItem.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .where((s) => s.classId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static ClassEntity? _mapStudentClassToEntity(Map<String, dynamic> m) {
    final id = m['_id']?.toString() ?? m['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final subject = m['subject']?.toString() ?? '';
    final gradeLevel = m['gradeLevel']?.toString() ?? '';
    final className = m['className']?.toString() ?? '';
    final name = className.isNotEmpty
        ? className
        : '${subject.isNotEmpty ? subject : 'Class'}${gradeLevel.isNotEmpty ? ' - $gradeLevel' : ''}';

    final teacherId = m['teacher']?.toString() ?? '';
    final teacherName = m['teacherName']?.toString() ?? '';

    int students = 0;
    final totalStudents = m['totalStudents'];
    if (totalStudents is int) students = totalStudents;
    if (students == 0 && totalStudents != null) {
      students = int.tryParse(totalStudents.toString()) ?? 0;
    }
    if (students == 0 && m['students'] is List) {
      students = (m['students'] as List).length;
    }

    final schedule = _formatSchedule(m['schedule']);

    return ClassEntity(
      id: id,
      name: name,
      subject: subject,
      category: '',
      teacher: teacherName,
      teacherId: teacherId,
      students: students,
      color: '#1F3C88',
      schedule: schedule,
      room: '',
      level: gradeLevel,
      schoolYear: '',
      gradeId: m['gradeId']?.toString(),
      subjectId: m['subjectId']?.toString(),
    );
  }

  static String _formatSchedule(dynamic schedule) {
    if (schedule == null) return '';
    if (schedule is String) return schedule;
    if (schedule is! List || schedule.isEmpty) return '';
    const dayNames = {
      'sun': 'Sun',
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat'
    };
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

  static List<LessonEntity> _parseLessonDetails(dynamic raw, String fallbackClassId) {
    if (raw is! List) return [];
    final out = <LessonEntity>[];
    for (final e in raw) {
      final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final lesson = _lessonFromJson(map, fallbackClassId);
      if (lesson != null) out.add(lesson);
    }
    return out;
  }

  static LessonEntity? _lessonFromJson(Map<String, dynamic> m, String fallbackClassId) {
    final id = m['_id']?.toString() ?? m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final classId = m['classId']?.toString() ?? fallbackClassId;
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

  static List<AssignmentEntity> _parseAssignmentDetails(dynamic raw, String fallbackClassId) {
    if (raw is! List) return [];
    final out = <AssignmentEntity>[];
    for (final e in raw) {
      final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final a = _assignmentFromJson(map, fallbackClassId);
      if (a != null) out.add(a);
    }
    return out;
  }

  static AssignmentEntity? _assignmentFromJson(Map<String, dynamic> m, String fallbackClassId) {
    final id = m['_id']?.toString() ?? m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final classId = m['classId']?.toString() ?? fallbackClassId;
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
    // Student class detail API: `status` is assignment lifecycle (e.g. active/closed).
    // Student progress uses `myStatus` (pending / submitted / graded).
    final myStatusRaw = m['myStatus']?.toString().trim().toLowerCase() ?? '';
    final fallbackStatus = (m['status']?.toString() ?? 'pending').toLowerCase();
    final statusStr =
        myStatusRaw.isNotEmpty ? myStatusRaw : fallbackStatus;
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
}
