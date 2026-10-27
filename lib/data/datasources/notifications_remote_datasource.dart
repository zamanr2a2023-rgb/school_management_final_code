import 'dart:convert';

import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsRemoteDatasource {
  NotificationsRemoteDatasource(this._prefs) : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  String? get _token => _prefs.getString(AppConstants.sessionTokenKey);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  Future<List<Map<String, dynamic>>> fetchMyNotifications({
    int page = 1,
    int limit = 50,
  }) async {
    if (!isConfigured || _token == null || _token!.isEmpty) return [];

    final uri = Uri.parse('$_apiBase/notifications/me').replace(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return [];

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      final data = decoded?['data'];
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  Future<void> markReadOnServer(String userNotificationId) async {
    if (!isConfigured ||
        _token == null ||
        _token!.isEmpty ||
        userNotificationId.isEmpty) {
      return;
    }

    final uri =
        Uri.parse('$_apiBase/notifications/$userNotificationId/read');
    final response = await http.patch(uri, headers: _headers);
    if (response.statusCode != 200) return;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {}
  }
}
