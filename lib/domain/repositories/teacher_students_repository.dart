import '../entities/teacher_roster_student_entity.dart';

/// Teacher roster: GET /teachers/students when API configured; else mock-backed list.
abstract class TeacherStudentsRepository {
  Future<TeacherStudentsListResult> listStudents(String searchQuery);

  /// GET /teachers/students/:id when API configured; else mock-backed roster match.
  Future<TeacherRosterStudentEntity?> getStudentDetail(String studentId);
}
