import '../entities/live_session_entity.dart';
import '../entities/teacher_live_sessions_overview.dart';

abstract class LiveSessionsRepository {
  Future<List<LiveSessionEntity>> getLiveSessions();
  /// Student: GET /sessions/student?status=approved (or status=ongoing). Returns API data when configured.
  Future<List<LiveSessionEntity>> getStudentLiveSessions({String? status});
  /// Teacher: GET /sessions/teacher when API configured; otherwise mock split (no completed list).
  Future<TeacherLiveSessionsOverview> getTeacherSessionsOverview();
  /// True when teacher session list/create can use the remote API ([AppConstants.apiBaseUrl] + token).
  bool get teacherSessionsApiConfigured;
  /// POST /sessions when API configured; otherwise appends to mock list.
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
  });
  Future<void> addLiveSession(LiveSessionEntity session);
}
