import '../entities/teacher_roster_student_entity.dart';

/// Teacher roster: GET /teachers/students when API configured; else mock-backed list.
abstract class TeacherStudentsRepository {
  Future<TeacherStudentsListResult> listStudents(String searchQuery);
}
