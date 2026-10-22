enum LessonType { text, pdf, video }
enum LessonStatus { draft, published }

class LessonEntity {
  final String id;
  final String classId;
  final String title;
  final String description;
  final LessonType type;
  final String content;
  final String date;
  final String? duration;
  final LessonStatus status;
  final String lastUpdated;
  final String? module;
  /// First attachment from API `attachments[]` (url is also in [content] when set).
  final String? attachmentMimeType;
  final String? attachmentName;

  /// True when the lesson was uploaded by an admin (shared grade/subject content).
  final bool uploadedByAdmin;

  const LessonEntity({
    required this.id,
    required this.classId,
    required this.title,
    required this.description,
    required this.type,
    required this.content,
    required this.date,
    this.duration,
    required this.status,
    required this.lastUpdated,
    this.module,
    this.attachmentMimeType,
    this.attachmentName,
    this.uploadedByAdmin = false,
  });
}
