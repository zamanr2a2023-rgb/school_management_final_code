import '../entities/class_entity.dart';
import '../entities/teacher_class_detail_result.dart';

/// Teacher classes: GET /classes/my and GET /classes/:classId.
/// Use for teacher classes list and class details; falls back to [ClassesRepository] when API not configured.
abstract class TeacherClassesRepository {
  /// GET /classes/my when API configured; else fallback by teacherId.
  Future<List<ClassEntity>> getMyClasses(String? teacherIdForFallback);

  /// GET /classes/:classId when API configured; else fallback.
  Future<ClassEntity?> getClassById(String classId);

  /// Full class payload (lessons, assignments, students, live, analytics) when API configured; else null.
  Future<TeacherClassDetailResult?> getClassDetailById(String classId);
}
