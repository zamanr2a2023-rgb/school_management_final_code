import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/student_entity.dart';

/// Analytics block from GET /classes/:classId (teacher).
class TeacherClassAnalytics {
  const TeacherClassAnalytics({
    required this.avgGrade,
    required this.avgAttendance,
    required this.totalStudents,
    required this.totalLessons,
    required this.totalAssignments,
    required this.totalLiveSessions,
  });

  final double avgGrade;
  final double avgAttendance;
  final int totalStudents;
  final int totalLessons;
  final int totalAssignments;
  final int totalLiveSessions;
}

/// Full teacher class payload: header + lessons + assignments + students + live + analytics.
class TeacherClassDetailResult {
  const TeacherClassDetailResult({
    required this.classEntity,
    required this.lessons,
    required this.assignments,
    required this.students,
    required this.liveSessions,
    this.analytics,
  });

  final ClassEntity classEntity;
  final List<LessonEntity> lessons;
  final List<AssignmentEntity> assignments;
  final List<StudentEntity> students;
  final List<LiveSessionEntity> liveSessions;
  final TeacherClassAnalytics? analytics;
}
