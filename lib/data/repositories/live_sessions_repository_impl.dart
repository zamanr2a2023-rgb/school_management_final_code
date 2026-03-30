import 'package:high_school/data/datasources/mock_data.dart';
import 'package:high_school/data/datasources/student_live_sessions_remote_datasource.dart';
import 'package:high_school/data/datasources/teacher_live_sessions_remote_datasource.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/teacher_live_sessions_overview.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveSessionsRepositoryImpl implements LiveSessionsRepository {
  LiveSessionsRepositoryImpl(SharedPreferences prefs)
      : _studentSessions = StudentLiveSessionsRemoteDatasource(prefs),
        _teacherSessions = TeacherLiveSessionsRemoteDatasource(prefs);

  final StudentLiveSessionsRemoteDatasource _studentSessions;
  final TeacherLiveSessionsRemoteDatasource _teacherSessions;

  @override
  Future<List<LiveSessionEntity>> getLiveSessions() async =>
      MockData.liveSessions;

  @override
  Future<List<LiveSessionEntity>> getStudentLiveSessions({String? status}) async {
    if (_studentSessions.isConfigured) {
      return _studentSessions.getSessions(status: status);
    }
    return getLiveSessions();
  }

  @override
  Future<TeacherLiveSessionsOverview> getTeacherSessionsOverview() async {
    if (_teacherSessions.isConfigured) {
      final remote = await _teacherSessions.fetchOverview();
      if (remote != null) return remote;
    }
    final all = await getLiveSessions();
    return TeacherLiveSessionsOverview(
      activeNow: all.where((s) => s.isActive).toList(),
      upcoming: all.where((s) => !s.isActive).toList(),
      completed: const [],
      fromRemote: false,
    );
  }

  @override
  bool get teacherSessionsApiConfigured => _teacherSessions.isConfigured;

  @override
  Future<CreateLiveSessionResult> createTeacherLiveSession({
    required String title,
    required String gradeId,
    required String subjectId,
    required String classId,
    required String className,
    required String date,
    required String time,
    required int duration,
    required String zoomLink,
  }) async {
    if (_teacherSessions.isConfigured) {
      return _teacherSessions.createSession(
        title: title,
        gradeId: gradeId,
        subjectId: subjectId,
        classId: classId,
        className: className,
        date: date,
        time: time,
        duration: duration,
        zoomLink: zoomLink,
      );
    }
    final link = zoomLink.trim();
    final isZoom = link.toLowerCase().contains('zoom');
    await addLiveSession(
      LiveSessionEntity(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        classId: classId,
        title: title.trim(),
        date: date.trim(),
        time: time.trim(),
        platform: isZoom ? LiveSessionPlatform.zoom : LiveSessionPlatform.meet,
        link: link,
        isActive: false,
        className: className.trim().isNotEmpty ? className.trim() : null,
        gradeLevel: null,
        subject: null,
        durationMinutes: duration,
      ),
    );
    return const CreateLiveSessionResult(success: true);
  }

  @override
  Future<void> addLiveSession(LiveSessionEntity session) async {
    MockData.liveSessions.add(session);
  }
}
