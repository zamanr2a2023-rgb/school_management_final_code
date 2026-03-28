import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/teacher_roster_student_entity.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GET /teachers/students?search=
class TeacherStudentsRemoteDatasource {
  TeacherStudentsRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase {
    final b = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return '$b/api/v1';
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<TeacherStudentsListResult?> fetchStudents({String search = ''}) async {
    if (!isConfigured) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('$_apiBase/teachers/students').replace(
      queryParameters: {'search': search},
    );
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
      final list = data is List ? data : <dynamic>[];
      final students = list
          .map((e) => _studentFromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .whereType<TeacherRosterStudentEntity>()
          .toList();
      final meta = decoded['meta'];
      var total = students.length;
      if (meta is Map<String, dynamic> && meta['total'] != null) {
        total = meta['total'] is int ? meta['total'] as int : int.tryParse(meta['total'].toString()) ?? total;
      }
      final classIds = <String>{};
      for (final s in students) {
        for (final c in s.classes) {
          if (c.classId.isNotEmpty) classIds.add(c.classId);
        }
      }
      return TeacherStudentsListResult(
        students: students,
        total: total,
        distinctClassCount: classIds.length,
      );
    } on UnauthorizedApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static TeacherRosterStudentEntity? _studentFromJson(Map<String, dynamic> m) {
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final name = m['name']?.toString() ?? '';
    final emailRaw = m['email'];
    final String? email = emailRaw == null ? null : emailRaw.toString().trim().isEmpty ? null : emailRaw.toString().trim();
    final phone = m['phone']?.toString() ?? '';
    final gradeLevel = m['gradeLevel']?.toString() ?? '';
    final subjects = <String>[];
    if (m['subjects'] is List) {
      for (final s in m['subjects'] as List) {
        if (s != null) subjects.add(s.toString());
      }
    }
    final avg = m['avgGrade'];
    final avgGrade = avg is num ? avg.toDouble() : double.tryParse(avg?.toString() ?? '') ?? 0;
    final classes = <TeacherRosterClassRef>[];
    if (m['classes'] is List) {
      for (final e in m['classes'] as List) {
        final cm = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
        final cid = cm['classId']?.toString() ?? '';
        classes.add(TeacherRosterClassRef(
          classId: cid,
          subject: cm['subject']?.toString() ?? '',
          gradeLevel: cm['gradeLevel']?.toString() ?? '',
        ));
      }
    }
    final cc = m['classesCount'];
    final classesCount = cc is int ? cc : int.tryParse(cc?.toString() ?? '') ?? classes.length;
    TeacherPerformanceOverviewEntity? perf;
    final po = m['performanceOverview'];
    if (po is Map) {
      final pom = Map<String, dynamic>.from(po);
      final og = pom['overallGrade'];
      final ar = pom['attendanceRate'];
      final ga = pom['gradedAssignments'];
      final ta = pom['totalAssignments'];
      perf = TeacherPerformanceOverviewEntity(
        overallGrade: og is num ? og.toDouble() : double.tryParse(og?.toString() ?? '') ?? 0,
        assignmentCompletion: pom['assignmentCompletion']?.toString() ?? '0/0',
        attendanceRate: ar is num ? ar.toDouble() : double.tryParse(ar?.toString() ?? '') ?? 0,
        lastActivity: pom['lastActivity']?.toString(),
        gradedAssignments: ga is int ? ga : int.tryParse(ga?.toString() ?? '') ?? 0,
        totalAssignments: ta is int ? ta : int.tryParse(ta?.toString() ?? '') ?? 0,
      );
    }
    final ap = <TeacherAssignmentProgressItemEntity>[];
    if (m['assignmentProgress'] is List) {
      for (final e in m['assignmentProgress'] as List) {
        final am = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
        final aid = am['assignmentId']?.toString() ?? '';
        if (aid.isEmpty) continue;
        final pts = am['points'];
        final sc = am['score'];
        ap.add(TeacherAssignmentProgressItemEntity(
          assignmentId: aid,
          title: am['title']?.toString() ?? '',
          dueAt: am['dueAt']?.toString(),
          points: pts is int ? pts : int.tryParse(pts?.toString() ?? '') ?? 0,
          status: am['status']?.toString() ?? 'pending',
          score: sc == null ? null : (sc is int ? sc : int.tryParse(sc.toString())),
          feedback: am['feedback']?.toString(),
          submittedAt: am['submittedAt']?.toString(),
        ));
      }
    }
    return TeacherRosterStudentEntity(
      id: id,
      name: name,
      email: email,
      phone: phone,
      gradeLevel: gradeLevel,
      subjects: subjects,
      avgGrade: avgGrade,
      classes: classes,
      classesCount: classesCount,
      performance: perf,
      assignmentProgress: ap,
    );
  }
}
