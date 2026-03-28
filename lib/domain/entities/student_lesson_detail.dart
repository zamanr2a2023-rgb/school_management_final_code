import 'package:high_school/domain/entities/lesson_entity.dart';

/// Payload from GET /api/v1/lesson/:lessonId (student).
class StudentLessonDetail {
  const StudentLessonDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.chapter,
    required this.gradeLabel,
    required this.subjectName,
    required this.contentTypeRaw,
    required this.dateIso,
    required this.statusRaw,
    required this.fileUrls,
    this.createdAt,
    this.updatedAt,
    this.duration,
  });

  final String id;
  final String title;
  final String description;
  final String chapter;
  final String gradeLabel;
  final String subjectName;
  /// API `contentType`: text | pdf | video
  final String contentTypeRaw;
  final String dateIso;
  final String statusRaw;
  final List<String> fileUrls;
  final String? createdAt;
  final String? updatedAt;
  final String? duration;

  LessonType get lessonType {
    switch (contentTypeRaw.toLowerCase()) {
      case 'video':
        return LessonType.video;
      case 'pdf':
        return LessonType.pdf;
      default:
        return LessonType.text;
    }
  }

  LessonStatus get lessonStatus =>
      statusRaw.toLowerCase() == 'draft' ? LessonStatus.draft : LessonStatus.published;

  /// Fallback from local mock [LessonEntity] when API is off.
  factory StudentLessonDetail.fromLessonEntity(LessonEntity e) {
    final typeStr = e.type == LessonType.video
        ? 'video'
        : (e.type == LessonType.pdf ? 'pdf' : 'text');
    final desc = e.type == LessonType.text && e.content.trim().isNotEmpty
        ? e.content
        : e.description;
    return StudentLessonDetail(
      id: e.id,
      title: e.title,
      description: desc,
      chapter: e.module ?? '',
      gradeLabel: '',
      subjectName: '',
      contentTypeRaw: typeStr,
      dateIso: e.date,
      statusRaw: e.status == LessonStatus.draft ? 'draft' : 'published',
      fileUrls: e.content.trim().isNotEmpty && (e.type == LessonType.video || e.type == LessonType.pdf)
          ? [e.content]
          : [],
      duration: e.duration,
    );
  }
}
