import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/student_profile_me_entity.dart';
import 'package:high_school/domain/entities/teacher_profile_me_entity.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GET /profiles/me (Auth), PATCH /profiles/me (Auth, multipart).
class StudentProfileRemoteDatasource {
  StudentProfileRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<Map<String, dynamic>?> _fetchProfileData() async {
    if (!isConfigured) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('$_apiBase/profiles/me');
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
      if (!_isSuccess(decoded)) return null;
      final data = decoded?['data'];
      if (data is! Map<String, dynamic>) return null;
      return data;
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// PATCH /profiles/me — `name`, `phone`, `address`; optional `profileImage` file.
  /// Tries JSON first when there is no image (many backends accept JSON); falls back to multipart.
  Future<bool> patchMyProfile({
    required String name,
    required String phone,
    required String address,
    String? profileImagePath,
  }) async {
    if (!isConfigured) return false;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse('$_apiBase/profiles/me');
    final hasImage = profileImagePath != null &&
        profileImagePath.isNotEmpty &&
        await File(profileImagePath).exists();

    if (hasImage) {
      return _patchMultipart(uri, token, name, phone, address,
          imagePath: profileImagePath);
    }

    if (await _patchMultipart(uri, token, name, phone, address,
        imagePath: null)) {
      return true;
    }
    return _tryJsonPatch(uri, token, name, phone, address);
  }

  Future<bool> _tryJsonPatch(
    Uri uri,
    String token,
    String name,
    String phone,
    String address,
  ) async {
    try {
      final response = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'address': address,
        }),
      );
      return _patchResponseOk(response);
    } catch (e, st) {
      debugPrint('patchMyProfile json: $e\n$st');
      return false;
    }
  }

  /// Sync call after [http.patch] completes (package:http is sync for response body).
  bool _patchResponseOk(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('patchMyProfile: ${response.statusCode} ${response.body}');
      return false;
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      try {
        ensureAuthorized(decoded);
      } on UnauthorizedApiException {
        return false;
      }
      return _isSuccess(decoded);
    } catch (e, st) {
      debugPrint('patchMyProfile parse: $e\n$st');
      return false;
    }
  }

  Future<bool> _patchMultipart(
    Uri uri,
    String token,
    String name,
    String phone,
    String address, {
    String? imagePath,
  }) async {
    final request = http.MultipartRequest('PATCH', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['phone'] = phone;
    request.fields['address'] = address;

    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        final filename = _basename(imagePath);
        request.files.add(
          await http.MultipartFile.fromPath(
            'profileImage',
            imagePath,
            filename: filename,
            contentType: _imageMediaTypeForFilename(filename),
          ),
        );
      }
    }

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _patchResponseOk(response);
    } catch (e, st) {
      debugPrint('patchMyProfile multipart: $e\n$st');
      return false;
    }
  }

  static String _basename(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i >= 0 ? path.substring(i + 1) : path;
  }

  static MediaType _imageMediaTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('application', 'octet-stream');
  }

  Future<StudentProfileMe?> getMyProfile() async {
    try {
      final data = await _fetchProfileData();
      if (data == null) return null;
      return _parseStudent(data);
    } on UnauthorizedApiException {
      return null;
    }
  }

  /// Teacher shape: `teachingOverview`, `assignedClasses`.
  Future<TeacherProfileMe?> getTeacherMyProfile() async {
    try {
      final data = await _fetchProfileData();
      if (data == null) return null;
      return _parseTeacher(data);
    } on UnauthorizedApiException {
      return null;
    }
  }

  static bool _isSuccess(Map<String, dynamic>? m) {
    if (m == null) return false;
    if (m['success'] == true) return true;
    final s = m['status']?.toString().toLowerCase();
    return s == 'success';
  }

  static StudentProfileMe? _parseStudent(Map<String, dynamic> data) {
    final userRaw = data['user'];
    if (userRaw is! Map) return null;
    final user = Map<String, dynamic>.from(userRaw);

    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    if (userId.isEmpty) return null;

    final profileDocId = data['_id']?.toString() ?? '';

    final name = user['name']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final role = user['role']?.toString() ?? '';
    final userStatus = user['status']?.toString() ?? '';

    final address = data['address']?.toString() ?? '';
    final profileImageUrl = _profileImageUrl(data['profileImage']);

    final academic = _parseAcademic(data['academicOverview']);
    final classes = _parseCurrentClasses(data['currentClasses']);

    return StudentProfileMe(
      userId: userId,
      profileDocumentId: profileDocId,
      name: name,
      phone: phone,
      role: role,
      userStatus: userStatus,
      address: address,
      profileImageUrl: profileImageUrl,
      academic: academic,
      currentClasses: classes,
    );
  }

  static String? _profileImageUrl(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) return v;
    if (v is Map) {
      final u = v['url']?.toString();
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

  static ProfileAcademicOverview _parseAcademic(dynamic raw) {
    if (raw is! Map) {
      return const ProfileAcademicOverview(
        totalClasses: 0,
        assignmentsDisplay: '—',
        averageGrade: 0,
        attendance: 0,
      );
    }
    final m = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw);
    final total = m['totalClasses'];
    final totalClasses = total is int ? total : int.tryParse(total?.toString() ?? '') ?? 0;
    final assignRaw = m['assignments'];
    final assignmentsDisplay = assignRaw == null
        ? '—'
        : assignRaw is String
            ? assignRaw
            : assignRaw.toString();
    final avg = m['averageGrade'];
    final averageGrade = avg is num ? avg : num.tryParse(avg?.toString() ?? '') ?? 0;
    final att = m['attendance'];
    final attendance = att is num ? att : num.tryParse(att?.toString() ?? '') ?? 0;
    return ProfileAcademicOverview(
      totalClasses: totalClasses,
      assignmentsDisplay: assignmentsDisplay.isEmpty ? '—' : assignmentsDisplay,
      averageGrade: averageGrade,
      attendance: attendance,
    );
  }

  static List<ProfileCurrentClass> _parseCurrentClasses(dynamic raw) {
    if (raw is! List) return [];
    final out = <ProfileCurrentClass>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e);
      final classId = m['classId']?.toString() ?? '';
      final subject = m['subject']?.toString() ?? '';
      final teacherName = m['teacherName']?.toString() ?? '';
      if (classId.isEmpty && subject.isEmpty) continue;
      out.add(ProfileCurrentClass(
        classId: classId,
        subject: subject.isEmpty ? '—' : subject,
        teacherName: teacherName.isEmpty ? '—' : teacherName,
      ));
    }
    return out;
  }

  static TeacherProfileMe? _parseTeacher(Map<String, dynamic> data) {
    final userRaw = data['user'];
    if (userRaw is! Map) return null;
    final user = Map<String, dynamic>.from(userRaw);

    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    if (userId.isEmpty) return null;

    final profileDocId = data['_id']?.toString() ?? '';
    final name = user['name']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final role = user['role']?.toString() ?? '';
    final userStatus = user['status']?.toString() ?? '';
    final address = data['address']?.toString() ?? '';
    final profileImageUrl = _profileImageUrl(data['profileImage']);
    final overview = _parseTeachingOverview(data['teachingOverview']);
    final assigned = _parseAssignedClasses(data['assignedClasses']);

    return TeacherProfileMe(
      userId: userId,
      profileDocumentId: profileDocId,
      name: name,
      phone: phone,
      role: role,
      userStatus: userStatus,
      address: address,
      profileImageUrl: profileImageUrl,
      teachingOverview: overview,
      assignedClasses: assigned,
    );
  }

  static TeacherTeachingOverview _parseTeachingOverview(dynamic raw) {
    if (raw is! Map) {
      return const TeacherTeachingOverview(
        totalClasses: 0,
        totalStudents: 0,
        totalAssignments: 0,
        totalGradedSubmissions: 0,
      );
    }
    final m = Map<String, dynamic>.from(raw);
    int n(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return TeacherTeachingOverview(
      totalClasses: n(m['totalClasses']),
      totalStudents: n(m['totalStudents']),
      totalAssignments: n(m['totalAssignments']),
      totalGradedSubmissions: n(m['totalGradedSubmissions']),
    );
  }

  static List<TeacherAssignedClass> _parseAssignedClasses(dynamic raw) {
    if (raw is! List) return [];
    final out = <TeacherAssignedClass>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final classId = m['classId']?.toString() ?? '';
      final className = m['className']?.toString() ?? '';
      final subject = m['subject']?.toString() ?? '';
      final gradeLevel = m['gradeLevel']?.toString() ?? '';
      final ts = m['totalStudents'];
      final totalStudents = ts is int ? ts : int.tryParse(ts?.toString() ?? '') ?? 0;
      if (classId.isEmpty && className.isEmpty) continue;
      out.add(TeacherAssignedClass(
        classId: classId,
        className: className.isNotEmpty ? className : subject,
        subject: subject,
        gradeLevel: gradeLevel,
        totalStudents: totalStudents,
      ));
    }
    return out;
  }
}
