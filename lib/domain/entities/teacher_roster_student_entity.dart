/// Class enrollment row from GET /teachers/students.
class TeacherRosterClassRef {
  const TeacherRosterClassRef({
    required this.classId,
    required this.subject,
    required this.gradeLevel,
  });

  final String classId;
  final String subject;
  final String gradeLevel;

  /// Chip label, e.g. "English · 5th".
  String get displayLabel {
    if (subject.isEmpty && gradeLevel.isEmpty) return classId;
    if (gradeLevel.isEmpty) return subject;
    if (subject.isEmpty) return gradeLevel;
    return '$subject · $gradeLevel';
  }
}

/// performanceOverview from teacher students API.
class TeacherPerformanceOverviewEntity {
  const TeacherPerformanceOverviewEntity({
    required this.overallGrade,
    required this.assignmentCompletion,
    required this.attendanceRate,
    this.lastActivity,
    required this.gradedAssignments,
    required this.totalAssignments,
  });

  final double overallGrade;
  final String assignmentCompletion;
  final double attendanceRate;
  final String? lastActivity;
  final int gradedAssignments;
  final int totalAssignments;
}

/// One row in assignmentProgress[].
class TeacherAssignmentProgressItemEntity {
  const TeacherAssignmentProgressItemEntity({
    required this.assignmentId,
    required this.title,
    this.dueAt,
    required this.points,
    required this.status,
    this.score,
    this.feedback,
    this.submittedAt,
  });

  final String assignmentId;
  final String title;
  final String? dueAt;
  final int points;
  final String status;
  final int? score;
  final String? feedback;
  final String? submittedAt;
}

/// One student from GET /api/v1/teachers/students.
class TeacherRosterStudentEntity {
  const TeacherRosterStudentEntity({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.gradeLevel,
    required this.subjects,
    required this.avgGrade,
    required this.classes,
    required this.classesCount,
    this.performance,
    required this.assignmentProgress,
  });

  final String id;
  final String name;
  final String? email;
  final String phone;
  final String gradeLevel;
  final List<String> subjects;
  final double avgGrade;
  final List<TeacherRosterClassRef> classes;
  final int classesCount;
  final TeacherPerformanceOverviewEntity? performance;
  final List<TeacherAssignmentProgressItemEntity> assignmentProgress;

  /// Grade badge as integer percent (API avgGrade may be double).
  int get avgGradePercent => avgGrade.round().clamp(0, 100);

  String get primaryContact {
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    return phone;
  }

  bool get hasEmail => email != null && email!.trim().isNotEmpty;
}

/// Result of listing teacher students (API or mock).
class TeacherStudentsListResult {
  const TeacherStudentsListResult({
    required this.students,
    required this.total,
    required this.distinctClassCount,
  });

  final List<TeacherRosterStudentEntity> students;
  final int total;
  final int distinctClassCount;

  double get averageGradePercent {
    if (students.isEmpty) return 0;
    final sum = students.fold<double>(0, (s, e) => s + e.avgGrade);
    return sum / students.length;
  }
}
