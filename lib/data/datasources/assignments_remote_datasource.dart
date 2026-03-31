import 'dart:convert';
import 'dart:io';

import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Teacher: POST /assignments (`multipart/form-data`).
class AssignmentsRemoteDatasource {
  AssignmentsRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase {
    final b = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return '$b/api/v1';
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// GET /assignments/:assignmentId/submissions — `data`: `{ assignment, submissions }`, `success`: bool.
  Future<AssignmentEntity?> fetchAssignmentSubmissions(String assignmentId) async {
    if (!isConfigured || assignmentId.trim().isEmpty) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse(
      '$_apiBase/assignments/${Uri.encodeComponent(assignmentId.trim())}/submissions',
    );
    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      return _parseAssignmentSubmissionsResponse(decoded);
    } on UnauthorizedApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static AssignmentEntity? _parseAssignmentSubmissionsResponse(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    final data = decoded['data'];
    if (data is! Map) return null;
    final dm = Map<String, dynamic>.from(data);
    final rawAssign = dm['assignment'];
    if (rawAssign is! Map) return null;
    final am = Map<String, dynamic>.from(rawAssign);

    final id = am['_id']?.toString() ?? am['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final classId = am['classId']?.toString() ?? '';

    String? subjectName;
    String? gradeLabel;
    final subj = am['subjectId'];
    if (subj is Map) {
      subjectName = Map<String, dynamic>.from(subj)['name']?.toString();
    }
    final grade = am['gradeId'];
    if (grade is Map) {
      gradeLabel = Map<String, dynamic>.from(grade)['label']?.toString();
    }
    final classInfo = am['classInfo'];
    if (classInfo is Map) {
      final ci = Map<String, dynamic>.from(classInfo);
      subjectName ??= ci['subject']?.toString();
      gradeLabel ??= ci['gradeLevel']?.toString();
    }

    final attachments = <AssignmentAttachmentEntity>[];
    final attRaw = am['attachments'];
    if (attRaw is List) {
      for (final e in attRaw) {
        if (e is! Map) continue;
        final em = Map<String, dynamic>.from(e);
        final url = em['url']?.toString();
        final name = em['originalName']?.toString() ?? 'file';
        final sz = em['size'];
        attachments.add(
          AssignmentAttachmentEntity(
            originalName: name,
            mimeType: em['mimeType']?.toString(),
            size: sz is int ? sz : int.tryParse(sz?.toString() ?? ''),
            url: url != null && url.isNotEmpty ? url : null,
          ),
        );
      }
    }

    final statusStr = (am['status']?.toString() ?? 'active').toLowerCase();
    var assignStatus = AssignmentStatus.pending;
    if (statusStr == 'submitted') assignStatus = AssignmentStatus.submitted;
    if (statusStr == 'graded') assignStatus = AssignmentStatus.graded;

    final submissions = <SubmissionEntity>[];
    final subsRaw = dm['submissions'];
    if (subsRaw is List) {
      for (final e in subsRaw) {
        if (e is! Map) continue;
        final sm = Map<String, dynamic>.from(e);
        final sub = _parseTeacherSubmission(sm, id);
        if (sub != null) submissions.add(sub);
      }
    }

    return AssignmentEntity(
      id: id,
      classId: classId,
      title: am['title']?.toString() ?? '',
      description: am['description']?.toString() ?? '',
      dueDate: am['dueAt']?.toString() ?? '',
      points: _toIntPoints(am['points']),
      status: assignStatus,
      grade: null,
      feedback: null,
      submissions: submissions.isEmpty ? null : submissions,
      subjectName: subjectName,
      gradeLabel: gradeLabel,
      attachments: attachments.isEmpty ? null : attachments,
    );
  }

  static int _toIntPoints(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// PATCH /submission/submissions/:submissionId/grade — body: `{ score, feedback }`.
  Future<({bool ok, String? message})> gradeSubmission({
    required String submissionId,
    required int score,
    required String feedback,
  }) async {
    if (!isConfigured || submissionId.trim().isEmpty) {
      return (ok: false, message: 'API not configured');
    }
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) {
      return (ok: false, message: 'Not signed in');
    }

    final uri = Uri.parse(
      '$_apiBase/submission/submissions/${Uri.encodeComponent(submissionId.trim())}/grade',
    );
    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'score': score,
          'feedback': feedback.trim(),
        }),
      );

      Map<String, dynamic>? decoded;
      final raw = response.body.trim();
      if (raw.isNotEmpty) {
        try {
          final j = jsonDecode(response.body);
          if (j is Map<String, dynamic>) {
            decoded = j;
          } else if (j is Map) {
            decoded = Map<String, dynamic>.from(j);
          }
        } catch (_) {
          decoded = null;
        }
      }
      if (decoded != null) ensureAuthorized(decoded);

      final code = response.statusCode;
      if (code == 200 || code == 201) {
        final success = decoded?['success'] == true ||
            decoded?['success'] == 1 ||
            (decoded?['status']?.toString().toLowerCase() == 'success') ||
            (decoded?['data'] != null);
        if (success || decoded == null) {
          return (ok: true, message: null);
        }
      }

      final msg = decoded?['message']?.toString() ??
          (raw.isNotEmpty ? raw : 'Request failed ($code)');
      return (ok: false, message: msg);
    } on UnauthorizedApiException {
      return (ok: false, message: 'Unauthorized');
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  static SubmissionEntity? _parseTeacherSubmission(Map<String, dynamic> m, String assignmentId) {
    final sidRaw = m['studentId'];
    var studentId = '';
    var studentName = '';
    if (sidRaw is Map) {
      final sm = Map<String, dynamic>.from(sidRaw);
      studentId = sm['_id']?.toString() ?? sm['id']?.toString() ?? '';
      studentName = sm['name']?.toString() ?? '';
    } else if (sidRaw != null) {
      studentId = sidRaw.toString();
    }
    if (studentName.isEmpty) studentName = studentId.isNotEmpty ? studentId : 'Student';

    final subId = m['_id']?.toString() ?? m['id']?.toString() ?? '';
    final submittedAt = m['submittedAt']?.toString() ?? '';
    if (subId.isEmpty && submittedAt.isEmpty && studentId.isEmpty) return null;

    final g = m['grade'] ?? m['score'];
    int? gradeVal;
    if (g != null) {
      if (g is int) {
        gradeVal = g;
      } else if (g is num) {
        gradeVal = g.round();
      } else {
        gradeVal = int.tryParse(g.toString());
      }
    }

    String? fileUrl;
    final file = m['file'];
    if (file is Map) {
      fileUrl = Map<String, dynamic>.from(file)['url']?.toString();
    }

    return SubmissionEntity(
      id: subId.isNotEmpty ? subId : '${studentId}_$submittedAt',
      assignmentId: assignmentId,
      studentId: studentId.isNotEmpty ? studentId : 'unknown',
      studentName: studentName,
      fileUrl: fileUrl,
      text: m['textAnswer']?.toString() ?? m['text']?.toString(),
      submittedAt: submittedAt.isNotEmpty ? submittedAt : '—',
      status: m['status']?.toString(),
      grade: gradeVal,
      feedback: m['feedback']?.toString(),
    );
  }

  /// POST /assignments — form keys match API: [file] optional (singular).
  Future<bool> createAssignment({
    required String title,
    required String description,
    required String dueDate,
    required String dueTime,
    required String points,
    required String gradeId,
    required String subjectId,
    required String classId,
    String? filePath,
  }) async {
    if (!isConfigured) return false;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse('$_apiBase/assignments');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['dueDate'] = dueDate;
    request.fields['dueTime'] = dueTime;
    request.fields['points'] = points;
    request.fields['gradeId'] = gradeId;
    request.fields['subjectId'] = subjectId;
    request.fields['classId'] = classId;

    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        final filename = _basename(file.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
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

  /// PATCH /assignments/:assignmentId — `multipart/form-data`; [file] optional. gradeId/subjectId/classId optional.
  Future<bool> patchAssignment({
    required String assignmentId,
    required String title,
    required String description,
    required String dueDate,
    required String dueTime,
    required String points,
    String? gradeId,
    String? subjectId,
    String? classId,
    String? filePath,
  }) async {
    if (!isConfigured || assignmentId.isEmpty) return false;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse('$_apiBase/assignments/$assignmentId');
    final request = http.MultipartRequest('PATCH', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['dueDate'] = dueDate;
    request.fields['dueTime'] = dueTime;
    request.fields['points'] = points;

    final g = gradeId?.trim() ?? '';
    final s = subjectId?.trim() ?? '';
    final c = classId?.trim() ?? '';
    if (g.isNotEmpty) request.fields['gradeId'] = g;
    if (s.isNotEmpty) request.fields['subjectId'] = s;
    if (c.isNotEmpty) request.fields['classId'] = c;

    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        final filename = _basename(file.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
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
      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
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

  /// DELETE /assignments/:assignmentId — e.g. `{ "success": true, "data": { "deleted": true, "assignmentId": "..." } }`.
  Future<bool> deleteAssignment(String assignmentId) async {
    if (!isConfigured || assignmentId.isEmpty) return false;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse('$_apiBase/assignments/$assignmentId');
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
    if (lower.endsWith('.doc')) return MediaType('application', 'msword');
    if (lower.endsWith('.docx')) {
      return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
    }
    return MediaType('application', 'octet-stream');
  }
}
