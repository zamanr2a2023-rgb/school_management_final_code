import '../entities/assignment_entity.dart';

abstract class AssignmentsRepository {
  Future<List<AssignmentEntity>> getAssignments({String? classId});
  Future<AssignmentEntity?> getAssignmentById(String id);
  Future<void> addAssignment(AssignmentEntity assignment);

  /// Teacher: PATCH submission grade. Returns `(ok: true)` on success.
  Future<({bool ok, String? message})> gradeSubmission({
    required String submissionId,
    required int score,
    required String feedback,
  });
}
