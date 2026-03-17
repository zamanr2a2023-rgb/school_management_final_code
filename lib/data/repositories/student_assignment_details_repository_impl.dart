import 'package:high_school/data/datasources/student_assignment_details_remote_datasource.dart';
import 'package:high_school/domain/entities/assignment_detail_result.dart';
import 'package:high_school/domain/repositories/student_assignment_details_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentAssignmentDetailsRepositoryImpl
    implements StudentAssignmentDetailsRepository {
  StudentAssignmentDetailsRepositoryImpl(SharedPreferences prefs)
      : _remote = StudentAssignmentDetailsRemoteDatasource(prefs);

  final StudentAssignmentDetailsRemoteDatasource _remote;

  @override
  Future<AssignmentDetailResult?> getAssignmentDetail(String assignmentId) =>
      _remote.getAssignmentDetail(assignmentId);

  @override
  Future<bool> submitAssignment(
    String assignmentId, {
    String? textAnswer,
    String? filePath,
  }) =>
      _remote.submitAssignment(
        assignmentId: assignmentId,
        textAnswer: textAnswer,
        filePath: filePath,
      );
}
