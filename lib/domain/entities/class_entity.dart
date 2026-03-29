class ClassEntity {
  final String id;
  final String name;
  final String subject;
  final String category;
  final String teacher;
  final String teacherId;
  final int students;
  final String color;
  final String schedule;
  final String room;
  final String level;
  final String schoolYear;
  /// From API (e.g. GET /classes/:id). Required for teacher POST /lesson.
  final String? gradeId;
  final String? subjectId;

  const ClassEntity({
    required this.id,
    required this.name,
    required this.subject,
    required this.category,
    required this.teacher,
    required this.teacherId,
    required this.students,
    required this.color,
    required this.schedule,
    required this.room,
    required this.level,
    required this.schoolYear,
    this.gradeId,
    this.subjectId,
  });
}
