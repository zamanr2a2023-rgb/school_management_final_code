import 'package:high_school/data/datasources/assignments_remote_datasource.dart';
import 'package:high_school/data/datasources/mock_data.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssignmentsRepositoryImpl implements AssignmentsRepository {
  AssignmentsRepositoryImpl(SharedPreferences prefs) : _remote = AssignmentsRemoteDatasource(prefs);

  final AssignmentsRemoteDatasource _remote;

  @override
  Future<List<AssignmentEntity>> getAssignments({String? classId}) async {
    var list = MockData.assignments;
    if (classId != null) list = list.where((a) => a.classId == classId).toList();
    return list;
  }

  @override
  Future<AssignmentEntity?> getAssignmentById(String id) async {
    if (_remote.isConfigured) {
      final fromApi = await _remote.fetchAssignmentSubmissions(id);
      if (fromApi != null) return fromApi;
    }
    try {
      final a = MockData.assignments.firstWhere((x) => x.id == id);
      final subs = MockData.submissions.where((s) => s.assignmentId == id).toList();
      return AssignmentEntity(
        id: a.id,
        classId: a.classId,
        title: a.title,
        description: a.description,
        dueDate: a.dueDate,
        points: a.points,
        status: a.status,
        grade: a.grade,
        feedback: a.feedback,
        submissions: subs.isNotEmpty ? subs : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addAssignment(AssignmentEntity assignment) async {
    MockData.assignments.add(assignment);
  }

  @override
  Future<({bool ok, String? message})> gradeSubmission({
    required String submissionId,
    required int score,
    required String feedback,
  }) async {
    if (_remote.isConfigured) {
      return _remote.gradeSubmission(
        submissionId: submissionId,
        score: score,
        feedback: feedback,
      );
    }
    return (ok: false, message: 'API not configured');
  }
}
