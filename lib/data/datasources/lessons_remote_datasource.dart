import 'dart:convert';
import 'dart:io';

import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Teacher/Admin: POST /lesson, PATCH /lesson/:id (`multipart/form-data`), DELETE /lesson/:id.
class LessonsRemoteDatasource {
  LessonsRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase {
    final b = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return '$b/api/v1';
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// Returns true when server accepts the lesson (200/201 + success).
  Future<bool> createLesson({
    required String title,
    required String description,
    required String contentType,
    required String chapter,
    required String status,
    required String gradeId,
    required String subjectId,
    required String classId,
    String? date,
    String? filePath,
  }) async {
    if (!isConfigured) return false;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return false;

    final needsFile = contentType == 'pdf' || contentType == 'video';
    if (needsFile && (filePath == null || filePath.isEmpty)) return false;

    final uri = Uri.parse('$_apiBase/lesson');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['contentType'] = contentType;
    request.fields['chapter'] = chapter;
    request.fields['status'] = status;
    request.fields['gradeId'] = gradeId;
    request.fields['subjectId'] = subjectId;
    request.fields['classId'] = classId;
    if (date != null && date.trim().isNotEmpty) {
      request.fields['date'] = date.trim();
    }

    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        final filename = _basename(file.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path,
            filename: filename,
            contentType: _mediaTypeForFilename(filename),
          ),
        );
      } else if (needsFile) {
        return false;
      }
    }

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      if (decoded?['success'] == true) return true;
      final st = decoded?['status']?.toString().toLowerCase();
      if (st == 'success') return true;
      if (decoded?['data'] != null) return true;
      return response.statusCode == 201;
    } on UnauthorizedApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// PATCH /lesson/:lessonId — same form fields as [createLesson]; omit [filePath] to keep existing file.
  Future<bool> patchLesson({
    required String lessonId,
    required String title,
    required String description,
    required String contentType,
    required String chapter,
    required String status,
    required String gradeId,
    required String subjectId,
    required String classId,
    String? date,
    String? filePath,
  }) async {
    if (!isConfigured || lessonId.isEmpty) return false;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse('$_apiBase/lesson/$lessonId');
    final request = http.MultipartRequest('PATCH', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['contentType'] = contentType;
    request.fields['chapter'] = chapter;
    request.fields['status'] = status;
    request.fields['gradeId'] = gradeId;
    request.fields['subjectId'] = subjectId;
    request.fields['classId'] = classId;
    if (date != null && date.trim().isNotEmpty) {
      request.fields['date'] = date.trim();
    }

    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        final filename = _basename(file.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path,
            filename: filename,
            contentType: _mediaTypeForFilename(filename),
          ),
        );
      }
    }

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200 && response.statusCode != 204) {
        return false;
      }
      final body = response.body.trim();
      if (body.isEmpty) return true;
      final decoded = jsonDecode(body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      if (decoded?['success'] == true) return true;
      final st = decoded?['status']?.toString().toLowerCase();
      if (st == 'success') return true;
      if (decoded?['data'] != null) return true;
      return response.statusCode == 200;
    } on UnauthorizedApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /lesson/:lessonId — response e.g. `{ "success": true, "data": { "deleted": true } }`.
  Future<bool> deleteLesson(String lessonId) async {
    if (!isConfigured || lessonId.isEmpty) return false;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse('$_apiBase/lesson/$lessonId');
    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        return false;
      }
      final body = response.body.trim();
      if (body.isEmpty) return true;
      final decoded = jsonDecode(body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      if (decoded?['success'] == true) return true;
      final data = decoded?['data'];
      if (data is Map && data['deleted'] == true) return true;
      final st = decoded?['status']?.toString().toLowerCase();
      if (st == 'success') return true;
      return response.statusCode == 200 || response.statusCode == 204;
    } on UnauthorizedApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _basename(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i >= 0 ? path.substring(i + 1) : path;
  }

  static MediaType _mediaTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.mp4')) return MediaType('video', 'mp4');
    if (lower.endsWith('.mov')) return MediaType('video', 'quicktime');
    if (lower.endsWith('.webm')) return MediaType('video', 'webm');
    return MediaType('application', 'octet-stream');
  }
}
