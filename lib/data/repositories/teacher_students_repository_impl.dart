import 'package:high_school/data/datasources/mock_data.dart';
import 'package:high_school/data/datasources/teacher_students_remote_datasource.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/student_entity.dart';
import 'package:high_school/domain/entities/teacher_roster_student_entity.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/students_repository.dart';
import 'package:high_school/domain/repositories/teacher_students_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherStudentsRepositoryImpl implements TeacherStudentsRepository {
  TeacherStudentsRepositoryImpl(SharedPreferences prefs, this._studentsRepo, this._classesRepo)
      : _remote = TeacherStudentsRemoteDatasource(prefs);

  final StudentsRepository _studentsRepo;
  final ClassesRepository _classesRepo;
  final TeacherStudentsRemoteDatasource _remote;

  @override
  Future<TeacherStudentsListResult> listStudents(String searchQuery) async {
    if (_remote.isConfigured) {
      final r = await _remote.fetchStudents(search: searchQuery);
      if (r != null) return r;
    }
    return _fallbackList(searchQuery);
  }

  Future<TeacherStudentsListResult> _fallbackList(String searchQuery) async {
    final allStudents = await _studentsRepo.getStudents();
    final allClasses = await _classesRepo.getClasses();
    final q = searchQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? allStudents
        : allStudents.where((s) {
            return s.name.toLowerCase().contains(q) || s.email.toLowerCase().contains(q);
          }).toList();

    final roster = filtered.map((s) => _studentToRoster(s, allClasses)).toList();
    final classIds = <String>{};
    for (final s in roster) {
      for (final c in s.classes) {
        if (c.classId.isNotEmpty) classIds.add(c.classId);
      }
    }
    return TeacherStudentsListResult(
      students: roster,
      total: roster.length,
      distinctClassCount: classIds.isEmpty ? allClasses.length : classIds.length,
    );
  }

  TeacherRosterStudentEntity _studentToRoster(StudentEntity s, List<ClassEntity> allClasses) {
    final enrolled = _enrolledClassesForStudent(s.id, allClasses);
    final refs = enrolled
        .map((c) => TeacherRosterClassRef(classId: c.id, subject: c.subject, gradeLevel: c.level))
        .toList();
    return TeacherRosterStudentEntity(
      id: s.id,
      name: s.name,
      email: s.email.isNotEmpty ? s.email : null,
      phone: '',
      gradeLevel: enrolled.isNotEmpty ? enrolled.first.level : '',
      subjects: enrolled.map((c) => c.subject).toList(),
      avgGrade: s.grade.toDouble(),
      classes: refs,
      classesCount: refs.length,
      performance: null,
      assignmentProgress: const [],
    );
  }

  List<ClassEntity> _enrolledClassesForStudent(String studentId, List<ClassEntity> allClasses) {
    final subs = MockData.studentSubscriptions.where((x) => x.studentId == studentId).toList();
    if (subs.isNotEmpty) {
      final sub = subs.first;
      return sub.enrolledClassIds
          .map((id) {
            try {
              return allClasses.firstWhere((c) => c.id == id);
            } catch (_) {
              return null;
            }
          })
          .whereType<ClassEntity>()
          .toList();
    }
    return allClasses.take(3).toList();
  }
}
