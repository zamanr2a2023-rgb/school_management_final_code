/// GET /profiles/me — student (or auth) profile payload.
class ProfileAcademicOverview {
  const ProfileAcademicOverview({
    required this.totalClasses,
    required this.assignmentsDisplay,
    required this.averageGrade,
    required this.attendance,
  });

  final int totalClasses;
  /// e.g. "1/1" from API.
  final String assignmentsDisplay;
  final num averageGrade;
  final num attendance;
}

class ProfileCurrentClass {
  const ProfileCurrentClass({
    required this.classId,
    required this.subject,
    required this.teacherName,
  });

  final String classId;
  final String subject;
  final String teacherName;
}

class StudentProfileMe {
  const StudentProfileMe({
    required this.userId,
    required this.profileDocumentId,
    required this.name,
    required this.phone,
    required this.role,
    required this.userStatus,
    required this.address,
    this.profileImageUrl,
    required this.academic,
    required this.currentClasses,
  });

  final String userId;
  final String profileDocumentId;
  final String name;
  final String phone;
  final String role;
  final String userStatus;
  final String address;
  final String? profileImageUrl;
  final ProfileAcademicOverview academic;
  final List<ProfileCurrentClass> currentClasses;
}
