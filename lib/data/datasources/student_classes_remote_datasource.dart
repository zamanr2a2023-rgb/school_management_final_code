import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/student_class_item.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GET /classes/student/my (Student) — student's enrolled classes
class StudentClassesRemoteDatasource {
  StudentClassesRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '${_baseUrl}/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// GET /classes/student/:classId (Student) — returns a single class object.
  /// Uses auth token. Returns null on error/unauthorized.
  Future<ClassEntity?> getStudentClassById(String classId) async {
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
      return _mapStudentClassToEntity(data);
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
}
