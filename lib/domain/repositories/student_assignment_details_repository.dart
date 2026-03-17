import 'package:high_school/domain/entities/assignment_detail_result.dart';

abstract class StudentAssignmentDetailsRepository {
  /// Fetches assignment detail (and current student's submission if any) from API.
  /// Returns null if API is not configured or request fails.
  Future<AssignmentDetailResult?> getAssignmentDetail(String assignmentId);

  /// Submits the current student's assignment answer to the API.
  /// Returns true if the API reports success.
  Future<bool> submitAssignment(
    String assignmentId, {
    String? textAnswer,
    String? filePath,
  });
}
