import 'package:high_school/domain/entities/live_session_entity.dart';

/// Payload from GET /api/v1/sessions/teacher (`data.activeNow`, `upcoming`, `completed`).
class TeacherLiveSessionsOverview {
  const TeacherLiveSessionsOverview({
    required this.activeNow,
    required this.upcoming,
    required this.completed,
    this.fromRemote = false,
  });

  final List<LiveSessionEntity> activeNow;
  final List<LiveSessionEntity> upcoming;
  final List<LiveSessionEntity> completed;

  /// True when this snapshot came from the API (not mock fallback).
  final bool fromRemote;
}

/// Result of POST /api/v1/sessions (teacher create live session).
class CreateLiveSessionResult {
  const CreateLiveSessionResult({required this.success, this.message});

  final bool success;
  final String? message;
}
