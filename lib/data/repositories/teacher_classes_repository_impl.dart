import 'package:high_school/data/datasources/teacher_classes_remote_datasource.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/teacher_class_detail_result.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/teacher_classes_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherClassesRepositoryImpl implements TeacherClassesRepository {
  TeacherClassesRepositoryImpl(SharedPreferences prefs, this._classesFallback)
      : _remote = TeacherClassesRemoteDatasource(prefs);

  final TeacherClassesRemoteDatasource _remote;
  final ClassesRepository _classesFallback;

  @override
  Future<List<ClassEntity>> getMyClasses(String? teacherIdForFallback) async {
    if (_remote.isConfigured) return _remote.getMyClasses();
    if (teacherIdForFallback != null && teacherIdForFallback.isNotEmpty) {
      return _classesFallback.getClassesByTeacher(teacherIdForFallback);
    }
    return [];
  }

  @override
  Future<ClassEntity?> getClassById(String classId) async {
    if (_remote.isConfigured) return _remote.getClassById(classId);
    return _classesFallback.getClassById(classId);
  }

  @override
  Future<TeacherClassDetailResult?> getClassDetailById(String classId) async {
    if (_remote.isConfigured) return _remote.getClassDetailById(classId);
    return null;
  }
}
