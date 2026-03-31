import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/student_dashboard_entity.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentDashboardRemoteDatasource {
  StudentDashboardRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<StudentDashboardEntity?> getDashboard() async {
    if (!isConfigured) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;
    final uri = Uri.parse('$_apiBase/students/dashboard');
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
      return _parse(response.body);
    } on UnauthorizedApiException {
      return null;
    }
  }

  StudentDashboardEntity? _parse(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>?;
      if (decoded == null) return null;
      final data = decoded['data'];
      if (data == null) return null;
      final map = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      return StudentDashboardEntity.fromJson(map);
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
