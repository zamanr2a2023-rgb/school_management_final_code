import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/subject_entity.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Calls GET /subjects (Auth). Requires token when backend expects Auth.
class SubjectsRemoteDatasource {
  SubjectsRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// GET /subjects. Sends Authorization: Bearer <token> when token is stored.
  Future<List<SubjectEntity>> getSubjects() async {
    if (!isConfigured) return [];
    final uri = Uri.parse('$_apiBase/subjects/all');
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) return [];
    try {
      return _parseSubjectsResponse(response.body);
    } on UnauthorizedApiException {
      return [];
    }
  }

  List<SubjectEntity> _parseSubjectsResponse(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      if (decoded == null) return [];
      // Support both { "data": [...] } and { "status": "success", "data": [...] }
      final data = decoded['data'];
      if (data == null) return [];
      final list = data is List ? data : (data is Map ? [data] : null);
      if (list == null) return [];
      return list
          .map((e) => SubjectEntity.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .where((s) => s.id.isNotEmpty && s.name.isNotEmpty)
          .toList();
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }
}
