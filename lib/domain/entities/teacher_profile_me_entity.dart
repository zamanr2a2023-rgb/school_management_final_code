/// GET /profiles/me — teacher profile payload.
class TeacherTeachingOverview {
  const TeacherTeachingOverview({
    required this.totalClasses,
    required this.totalStudents,
    required this.totalAssignments,
    required this.totalGradedSubmissions,
  });

  final int totalClasses;
  final int totalStudents;
  final int totalAssignments;
  final int totalGradedSubmissions;
}

class TeacherAssignedClass {
  const TeacherAssignedClass({
    required this.classId,
    required this.className,
    required this.subject,
    required this.gradeLevel,
    required this.totalStudents,
  });

  final String classId;
  final String className;
  final String subject;
  final String gradeLevel;
  final int totalStudents;
}

class TeacherProfileMe {
  const TeacherProfileMe({
    required this.userId,
    required this.profileDocumentId,
    required this.name,
    required this.phone,
    required this.role,
    required this.userStatus,
    required this.address,
    this.profileImageUrl,
    required this.teachingOverview,
    required this.assignedClasses,
  });

  final String userId;
  final String profileDocumentId;
  final String name;
  final String phone;
  final String role;
  final String userStatus;
  final String address;
  final String? profileImageUrl;
  final TeacherTeachingOverview teachingOverview;
  final List<TeacherAssignedClass> assignedClasses;
}
