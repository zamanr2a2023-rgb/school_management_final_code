import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:http/http.dart' as http;

/// Response from POST /auth/login or POST /auth/register.
class AuthApiResponse {
  AuthApiResponse({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

/// Remote data source for auth APIs (login, register).
/// Uses base URL from [AppConstants.apiBaseUrl].
class AuthRemoteDatasource {
  AuthRemoteDatasource() : _baseUrl = AppConstants.apiBaseUrl;

  final String _baseUrl;

  String get _apiBase => _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// POST /otp/send
  /// Body: { "phone": "33445566" }
  Future<void> sendOtp(String phone) async {
    final uri = Uri.parse('$_apiBase/otp/send');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    if (decoded == null) throw AuthApiException('Invalid response');
    final status = decoded['status'] as String?;
    final success = decoded['success'] as bool?;
    if (status == 'fail' || success == false) {
      final message = decoded['message'] as String? ?? 'Failed to send OTP';
      throw AuthApiException(message);
    }
  }

  /// POST /otp/verify
  /// Body: { "phone": "33445566", "otp": "4821" }
  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final uri = Uri.parse('$_apiBase/otp/verify');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    if (decoded == null) throw AuthApiException('Invalid response');
    final status = decoded['status'] as String?;
    final success = decoded['success'] as bool?;
    if (status == 'fail' || success == false) {
      final message = decoded['message'] as String? ?? 'Invalid OTP';
      throw AuthApiException(message);
    }
  }

  /// POST /auth/login
  /// Body: { "phone": "...", "pin": "1234" }
  Future<AuthApiResponse> login(String phone, String pin) async {
    final uri = Uri.parse('$_apiBase/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'pin': pin}),
    );
    return _parseAuthResponse(response);
  }

  /// POST /auth/register
  /// Student: role, name, phone, pin, confirmPin, gradeLevel, assignedSubjects (labels)
  /// Teacher: role, name, phone, pin, confirmPin, subject, assignedGrades (labels)
  Future<AuthApiResponse> register({
    required String role,
    required String name,
    required String phone,
    required String pin,
    String? gradeId,
    String? gradeLevel,
    List<String>? assignedSubjectIds,
    List<String>? assignedSubjects,
    String? subjectId,
    String? subject,
    List<String>? assignedGradeIds,
    List<String>? assignedGrades,
  }) async {
    final uri = Uri.parse('$_apiBase/auth/register');
    final Map<String, dynamic> body = {
      'role': role,
      'name': name,
      'phone': phone,
      'pin': pin,
      'confirmPin': pin,
    };
    if (role == 'student') {
      if (gradeId != null) body['gradeId'] = gradeId;
      if (gradeLevel != null) body['gradeLevel'] = gradeLevel;
      if (assignedSubjectIds != null) body['assignedSubjectIds'] = assignedSubjectIds;
      if (assignedSubjects != null) body['assignedSubjects'] = assignedSubjects;
    } else if (role == 'teacher') {
      if (subjectId != null) body['subjectId'] = subjectId;
      if (subject != null) body['subject'] = subject;
      if (assignedGradeIds != null) body['assignedGradeIds'] = assignedGradeIds;
      if (assignedGrades != null) body['assignedGrades'] = assignedGrades;
    }
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parseAuthResponse(response);
  }

  /// GET /users/me (Auth). Returns raw `data` user map or null.
  Future<Map<String, dynamic>?> getUsersMe(String token) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_apiBase/users/me');
    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      if (decoded == null) return null;
      final success = decoded['success'];
      if (success != true) return null;
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  AuthApiResponse _parseAuthResponse(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    if (decoded == null) throw AuthApiException('Invalid response');

    final status = decoded['status'] as String?;
    final success = decoded['success'] as bool?;
    if (status == 'fail' || success == false) {
      final message = decoded['message'] as String? ?? 'Request failed';
      throw AuthApiException(message);
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) throw AuthApiException('No data in response');

    final token = data['token'] as String? ?? data['accessToken'] as String?;
    if (token == null || token.isEmpty) throw AuthApiException('No token in response');

    final user = data['user'] as Map<String, dynamic>? ?? data;
    if (user.isEmpty) throw AuthApiException('No user in response');

    return AuthApiResponse(token: token, user: user);
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
