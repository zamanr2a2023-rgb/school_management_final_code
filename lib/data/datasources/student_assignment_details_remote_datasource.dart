import 'dart:convert';
import 'dart:io';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/assignment_detail_result.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentAssignmentDetailsRemoteDatasource {
  StudentAssignmentDetailsRemoteDatasource(this._prefs)
      : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// POST /submission/:assignmentId/submit (Student, multipart/form-data).
  /// Sends the student's submission (optional text answer and optional file).
  Future<bool> submitAssignment({
    required String assignmentId,
    String? textAnswer,
    String? filePath,
  }) async {
    if (!isConfigured) return false;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse('$_apiBase/submission/$assignmentId/submit');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    if (textAnswer != null && textAnswer.trim().isNotEmpty) {
      request.fields['textAnswer'] = textAnswer.trim();
    }
    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200 && response.statusCode != 201) {
      return false;
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      final success = decoded?['success'] == true;
      return success;
    } on UnauthorizedApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// GET /assignments/:assignmentId (Student). Returns null if not configured, unauthorized, or error.
  Future<AssignmentDetailResult?> getAssignmentDetail(String assignmentId) async {
    if (!isConfigured) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;
    final uri = Uri.parse('$_apiBase/assignments/$assignmentId');
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
      return _parse(decoded);
    } on UnauthorizedApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  AssignmentDetailResult? _parse(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    final success = decoded['success'];
    if (success != true) return null;
    final data = decoded['data'];
    if (data == null || data is! Map<String, dynamic>) return null;
    final assignmentJson = data['assignment'];
    if (assignmentJson == null || assignmentJson is! Map<String, dynamic>) return null;
    final submissionJson = data['submission'];

    AssignmentEntity assignment = _assignmentFromJson(assignmentJson);
    final classInfo = _classInfoFromJson(
      assignmentJson['classInfo'],
      assignment.classId,
    );
    bool hasSubmission = false;
    String? submittedAt;
    String? submissionFileUrl;
    String? submissionFileName;
    String? submissionType;
    String submissionStatus = '';
    if (submissionJson != null && submissionJson is Map<String, dynamic>) {
      hasSubmission = true;
      submittedAt = submissionJson['submittedAt']?.toString();
      submissionType = submissionJson['submissionType']?.toString();
      submissionStatus = (submissionJson['status']?.toString() ?? '').toLowerCase();
      final file = submissionJson['file'];
      if (file is Map<String, dynamic>) {
        submissionFileUrl = file['url']?.toString();
        submissionFileName = file['originalName']?.toString();
      }
    }
    if (hasSubmission && submissionStatus == 'graded') {
      assignment = AssignmentEntity(
        id: assignment.id,
        classId: assignment.classId,
        title: assignment.title,
        description: assignment.description,
        dueDate: assignment.dueDate,
        points: assignment.points,
        status: AssignmentStatus.graded,
        grade: assignment.grade,
        feedback: assignment.feedback,
        submissions: assignment.submissions,
      );
    } else if (hasSubmission) {
      assignment = AssignmentEntity(
        id: assignment.id,
        classId: assignment.classId,
        title: assignment.title,
        description: assignment.description,
        dueDate: assignment.dueDate,
        points: assignment.points,
        status: AssignmentStatus.submitted,
        grade: assignment.grade,
        feedback: assignment.feedback,
        submissions: assignment.submissions,
      );
    }

    return AssignmentDetailResult(
      assignment: assignment,
      classInfo: classInfo,
      hasSubmission: hasSubmission,
      submittedAt: submittedAt,
      submissionFileUrl: submissionFileUrl,
      submissionFileName: submissionFileName,
      submissionType: submissionType,
    );
  }

  AssignmentEntity _assignmentFromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final classId = json['classId']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';
    final description = json['description']?.toString() ?? '';
    final dueAt = json['dueAt']?.toString() ?? '';
    final points = _toInt(json['points']);
    final statusStr = (json['status']?.toString() ?? 'active').toLowerCase();
    AssignmentStatus status = AssignmentStatus.pending;
    if (statusStr == 'submitted') status = AssignmentStatus.submitted;
    if (statusStr == 'graded') status = AssignmentStatus.graded;
    return AssignmentEntity(
      id: id,
      classId: classId,
      title: title,
      description: description,
      dueDate: dueAt,
      points: points,
      status: status,
      grade: null,
      feedback: null,
      submissions: null,
    );
  }

  ClassEntity? _classInfoFromJson(dynamic classInfoJson, String classId) {
    if (classInfoJson == null || classInfoJson is! Map<String, dynamic>) return null;
    final gradeLevel = classInfoJson['gradeLevel']?.toString() ?? '';
    final subject = classInfoJson['subject']?.toString() ?? '';
    final teacher = classInfoJson['teacher']?.toString() ?? '';
    final name = gradeLevel.isNotEmpty && subject.isNotEmpty
        ? '$gradeLevel - $subject'
        : (subject.isNotEmpty ? subject : 'Class');
    return ClassEntity(
      id: classId,
      name: name,
      subject: subject,
      category: '',
      teacher: teacher,
      teacherId: teacher,
      students: 0,
      color: '',
      schedule: '',
      room: '',
      level: gradeLevel,
      schoolYear: '',
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
