import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/timetable_entity.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Remote datasource for GET /students/timetable (student timetable).
class StudentTimetableRemoteDatasource {
  StudentTimetableRemoteDatasource(this._prefs)
      : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  static const Map<String, String> _dayCodeToEnglish = {
    'sun': 'Sunday',
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
    'sat': 'Saturday',
  };

  /// Returns timetable entries and API "today" day code. Uses [TimetableResult] shape.
  Future<_TimetableApiResult> getTimetableResult() async {
    if (!isConfigured) return const _TimetableApiResult([], null);
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return const _TimetableApiResult([], null);

    final uri = Uri.parse('$_apiBase/students/timetable');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) return const _TimetableApiResult([], null);
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) ensureAuthorized(decoded);
      return _parse(response.body);
    } on UnauthorizedApiException {
      return const _TimetableApiResult([], null);
    }
  }

  /// Parses API response: { success?, data: { today?, groupedByDay: { sun: [], mon: [], ... } } }.
  _TimetableApiResult _parse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return const _TimetableApiResult([], null);
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return const _TimetableApiResult([], null);

      final todayRaw = data['today'];
      final todayKey = todayRaw is String ? todayRaw.trim().toLowerCase() : null;

      final groupedByDayDynamic = data['groupedByDay'];
      if (groupedByDayDynamic is! Map) return _TimetableApiResult([], todayKey);

      final List<TimetableEntryEntity> entries = [];

      groupedByDayDynamic.forEach((key, value) {
        final dayCode = key.toString().toLowerCase();
        final englishDay = _dayCodeToEnglish[dayCode];
        if (englishDay == null) return;

        final slots = value is List ? value : <dynamic>[];
        for (final slotRaw in slots) {
          if (slotRaw is! Map) continue;
          final slot = slotRaw is Map<String, dynamic>
              ? slotRaw
              : Map<String, dynamic>.from(slotRaw);

          final classId = slot['classId']?.toString() ??
              slot['_id']?.toString() ??
              '';
          if (classId.isEmpty) continue;

          final subject = slot['subject']?.toString() ?? '';
          final gradeLevel = slot['gradeLevel']?.toString() ?? '';
          final className =
              gradeLevel.isNotEmpty ? '$subject - $gradeLevel' : (subject.isNotEmpty ? subject : 'Class');

          final teacherMap = slot['teacher'];
          String teacherName = '';
          if (teacherMap is Map<String, dynamic>) {
            teacherName = teacherMap['name']?.toString() ?? '';
          }

          final startTime = slot['startTime']?.toString() ?? '';
          final endTime = slot['endTime']?.toString() ?? '';
          final time = (startTime.isNotEmpty && endTime.isNotEmpty)
              ? '$startTime - $endTime'
              : (startTime.isNotEmpty ? startTime : '');

          final room = slot['room']?.toString() ?? '';
          final startMin = slot['startMin']?.toString() ?? '';

          entries.add(
            TimetableEntryEntity(
              id: '${classId}_${dayCode}_$startMin',
              day: englishDay,
              time: time,
              classId: classId,
              className: className,
              teacher: teacherName,
              room: room,
            ),
          );
        }
      });

      return _TimetableApiResult(entries, todayKey);
    } on UnauthorizedApiException {
      rethrow;
    } catch (_) {
      return const _TimetableApiResult([], null);
    }
  }
}

class _TimetableApiResult {
  const _TimetableApiResult(this.entries, this.todayKey);
  final List<TimetableEntryEntity> entries;
  final String? todayKey;
}

