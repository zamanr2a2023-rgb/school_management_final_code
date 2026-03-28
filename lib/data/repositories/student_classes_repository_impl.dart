import 'package:high_school/data/datasources/student_classes_remote_datasource.dart';
import 'package:high_school/domain/entities/student_class_detail_result.dart';
import 'package:high_school/domain/entities/student_class_item.dart';
import 'package:high_school/domain/repositories/student_classes_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentClassesRepositoryImpl implements StudentClassesRepository {
  StudentClassesRepositoryImpl(SharedPreferences prefs)
      : _remote = StudentClassesRemoteDatasource(prefs);

  final StudentClassesRemoteDatasource _remote;

  @override
  Future<List<StudentClassItem>> getStudentClasses() =>
      _remote.getStudentClasses();

  @override
  Future<StudentClassDetailResult?> getStudentClassDetail(String classId) =>
      _remote.getStudentClassDetail(classId);
}
