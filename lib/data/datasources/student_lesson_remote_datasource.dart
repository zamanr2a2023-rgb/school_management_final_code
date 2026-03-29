import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/student_lesson_detail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Student: GET /api/v1/lesson/:lessonId (Bearer).
class StudentLessonRemoteDatasource {
  StudentLessonRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase {
    final b = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return '$b/api/v1';
  }

  bool get isConfigured => _baseUrl.trim().isNotEmpty;

  Future<StudentLessonDetail?> getLessonDetail(String lessonId) async {
    if (!isConfigured) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('$_apiBase/lesson/$lessonId');
    try {
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode != 200) {
        debugPrint('StudentLessonRemoteDatasource: ${res.statusCode} ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>?;
      try {
        ensureAuthorized(decoded);
      } on UnauthorizedApiException {
        return null;
      }
      if (decoded == null || decoded['success'] != true) return null;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return null;
      return _parseDetail(data);
    } catch (e, st) {
      debugPrint('StudentLessonRemoteDatasource: $e\n$st');
      return null;
    }
  }

  static StudentLessonDetail _parseDetail(Map<String, dynamic> m) {
    final grade = m['gradeId'];
    String gradeLabel = '';
    if (grade is Map<String, dynamic>) {
      gradeLabel = (grade['label'] ?? grade['name'] ?? '').toString();
    }

    final subject = m['subjectId'];
    String subjectName = '';
    if (subject is Map<String, dynamic>) {
      subjectName = (subject['name'] ?? '').toString();
    }

    final files = _parseFiles(m['files']);

    return StudentLessonDetail(
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      chapter: (m['chapter'] ?? '').toString(),
      gradeLabel: gradeLabel,
      subjectName: subjectName,
      contentTypeRaw: (m['contentType'] ?? 'text').toString(),
      dateIso: (m['date'] ?? '').toString(),
      statusRaw: (m['status'] ?? 'published').toString(),
      fileUrls: files,
      createdAt: m['createdAt']?.toString(),
      updatedAt: m['updatedAt']?.toString(),
      duration: m['duration']?.toString(),
    );
  }

  static List<String> _parseFiles(dynamic raw) {
    if (raw is! List) return [];
    final out = <String>[];
    for (final e in raw) {
      if (e is String && e.trim().isNotEmpty) {
        out.add(e.trim());
      } else if (e is Map<String, dynamic>) {
        final u = e['url'] ?? e['path'] ?? e['file'] ?? e['link'];
        if (u is String && u.trim().isNotEmpty) out.add(u.trim());
      }
    }
    return out;
  }
}
