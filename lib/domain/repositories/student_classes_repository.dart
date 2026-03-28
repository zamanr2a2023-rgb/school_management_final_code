import '../entities/student_class_detail_result.dart';
import '../entities/student_class_item.dart';

abstract class StudentClassesRepository {
  /// GET /classes/student/my (Student). Returns list from API or empty when not configured/fails.
  Future<List<StudentClassItem>> getStudentClasses();

  /// GET /classes/student/:classId — class, lessonDetails, assignmentDetails. Null when not configured / error.
  Future<StudentClassDetailResult?> getStudentClassDetail(String classId);
}
