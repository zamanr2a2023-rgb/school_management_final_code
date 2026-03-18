import 'package:high_school/data/datasources/mock_data.dart';
import 'package:high_school/data/datasources/student_classes_remote_datasource.dart';
import 'package:high_school/data/datasources/teacher_classes_remote_datasource.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/student_class_item.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClassesRepositoryImpl implements ClassesRepository {
  ClassesRepositoryImpl(SharedPreferences prefs)
      : _studentRemote = StudentClassesRemoteDatasource(prefs),
        _teacherRemote = TeacherClassesRemoteDatasource(prefs);

  final StudentClassesRemoteDatasource _studentRemote;
  final TeacherClassesRemoteDatasource _teacherRemote;

  @override
  Future<List<ClassEntity>> getClasses() async => MockData.classes;

  @override
  Future<ClassEntity?> getClassById(String id) async {
    if (id.isEmpty) return null;

    // Student class details endpoint (best match for student flow).
    if (_studentRemote.isConfigured) {
      final cls = await _studentRemote.getStudentClassById(id);
      if (cls != null) return cls;
    }

    // Try teacher/admin class details endpoint when available.
    if (_teacherRemote.isConfigured) {
      final cls = await _teacherRemote.getClassById(id);
      if (cls != null) return cls;
    }

    // Student fallback: try enrolled classes API and map the matching classId.
    if (_studentRemote.isConfigured) {
      final List<StudentClassItem> items = await _studentRemote.getStudentClasses();
      for (final item in items) {
        if (item.classId == id) return item.toClassEntity();
      }
    }

    // Local fallback (legacy mock).
    try {
      return MockData.classes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ClassEntity>> getClassesByTeacher(String teacherId) async {
    return MockData.classes.where((c) => c.teacherId == teacherId).toList();
  }
}
