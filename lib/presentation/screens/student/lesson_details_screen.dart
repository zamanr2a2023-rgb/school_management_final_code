import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/core/utils/app_date_format.dart';
import 'package:high_school/data/datasources/student_lesson_remote_datasource.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/entities/student_lesson_detail.dart';
import 'package:high_school/domain/repositories/lessons_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/screens/teacher/teacher_lesson_media_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_pdf_attachment_screen.dart';
import 'package:high_school/presentation/widgets/lesson_video_player.dart';

class LessonDetailsScreen extends StatefulWidget {
  const LessonDetailsScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  State<LessonDetailsScreen> createState() => _LessonDetailsScreenState();
}

class _LessonDetailsScreenState extends State<LessonDetailsScreen> {
  Future<StudentLessonDetail?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<StudentLessonDetail?> _load() async {
    final remote = context.read<StudentLessonRemoteDatasource>();
    final lessonsRepo = context.read<LessonsRepository>();
    if (remote.isConfigured) {
      final api = await remote.getLessonDetail(widget.lessonId);
      if (api != null) return api;
    }
    if (!mounted) return null;
    final mock = await lessonsRepo.getLessonById(widget.lessonId);
    if (mock != null) return StudentLessonDetail.fromLessonEntity(mock);
    return null;
  }

  static String _textBody(StudentLessonDetail d) {
    if (d.description.trim().isNotEmpty) return d.description;
    if (d.chapter.trim().isNotEmpty) return d.chapter;
    return '';
  }

  static String? _formatDate(String iso) {
    if (iso.trim().isEmpty) return null;
    final formatted = AppDateFormat.date(iso);
    return formatted.isEmpty ? null : formatted;
  }

  static IconData _typeIcon(LessonType t) {
    switch (t) {
      case LessonType.video:
        return Icons.videocam_outlined;
      case LessonType.pdf:
        return Icons.picture_as_pdf_outlined;
      case LessonType.text:
        return Icons.article_outlined;
    }
  }

  static String _typeBadgeKey(LessonType t) {
    switch (t) {
      case LessonType.video:
        return 'video';
      case LessonType.pdf:
        return 'pdf';
      case LessonType.text:
        return 'text';
    }
  }

  static bool _urlLooksLikeImage(String url) {
    var lower = url.toLowerCase().trim();
    final raw = lower;
    try {
      final path = Uri.parse(url).path;
      if (path.isNotEmpty) lower = path.toLowerCase();
    } catch (_) {}
    lower = lower.split('?').first.split('#').first;
    const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'];
    if (imageExts.any(lower.endsWith)) return true;
    if (raw.contains('/image/') || raw.contains('image/upload')) return true;
    final seg = lower.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => '');
    final upper = seg.toUpperCase();
    return upper.startsWith('IMG-') || upper.startsWith('IMG_');
  }

  static String _mediaFileName(StudentLessonDetail lesson, String url) {
    try {
      final seg = Uri.parse(url).pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
      if (seg.isNotEmpty) {
        return Uri.decodeComponent(seg);
      }
    } catch (_) {}
    final title = lesson.title.trim();
    if (_urlLooksLikeImage(url)) {
      return title.isEmpty ? 'image' : title;
    }
    return title.isEmpty ? 'lesson.pdf' : '$title.pdf';
  }

  void _openMediaViewer(BuildContext context, StudentLessonDetail lesson, String url) {
    final fileName = _mediaFileName(lesson, url);
    if (_urlLooksLikeImage(url)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => TeacherLessonImageScreen(
            url: url,
            title: fileName,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => TeacherPdfAttachmentScreen(
          url: url,
          fileName: fileName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return FutureBuilder<StudentLessonDetail?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final lesson = snapshot.data;
        if (lesson == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                lang.t('lessons.lessonNotFound'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        final type = lesson.lessonType;
        final dateStr = _formatDate(lesson.dateIso);
        final primaryUrl = lesson.fileUrls.isNotEmpty ? lesson.fileUrls.first : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_typeIcon(type), size: 20, color: Colors.blue.shade700),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  label: Text(
                                    _typeBadgeKey(type),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: Colors.grey.shade200,
                                  side: BorderSide.none,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                if (lesson.gradeLabel.isNotEmpty)
                                  Text(
                                    lesson.gradeLabel,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                if (lesson.subjectName.isNotEmpty)
                                  Text(
                                    lesson.subjectName,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        lesson.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                      ),
                      if (lesson.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          lesson.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                                height: 1.45,
                              ),
                        ),
                      ],
                      if (lesson.chapter.trim().isNotEmpty &&
                          lesson.chapter.trim() != lesson.description.trim()) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${lang.t('teacherClassDetails.chapter')}: ${lesson.chapter}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                      if (dateStr != null || (lesson.duration != null && lesson.duration!.isNotEmpty)) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (dateStr != null) ...[
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                            if (dateStr != null &&
                                lesson.duration != null &&
                                lesson.duration!.isNotEmpty)
                              const SizedBox(width: 16),
                            if (lesson.duration != null && lesson.duration!.isNotEmpty) ...[
                              Icon(Icons.schedule_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text(
                                lesson.duration!,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildContent(context, lang, lesson, type, primaryUrl),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    LanguageProvider lang,
    StudentLessonDetail lesson,
    LessonType type,
    String? primaryUrl,
  ) {
    switch (type) {
      case LessonType.video:
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: primaryUrl != null && primaryUrl.isNotEmpty
              ? LessonVideoPlayer(url: primaryUrl)
              : Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_outlined, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          lang.t('lessons.videoPlayerPlaceholder'),
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      case LessonType.pdf:
        final isImage = primaryUrl != null && _urlLooksLikeImage(primaryUrl);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 10),
              Text(
                isImage ? lang.t('common.view') : lang.t('lessons.pdfDocument'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (!isImage) ...[
                const SizedBox(height: 4),
                Text(
                  lang.t('lessons.pdfOpenHint'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              if (primaryUrl != null && primaryUrl.isNotEmpty) ...[
                if (!isImage) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => downloadTeacherPdfAttachment(
                        context,
                        primaryUrl,
                        _mediaFileName(lesson, primaryUrl),
                      ),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(lang.t('lessons.downloadPDF')),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openMediaViewer(context, lesson, primaryUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(isImage ? lang.t('common.view') : lang.t('lessons.viewPdf')),
                  ),
                ),
              ] else
                Text(
                  lang.t('lessons.pdfOpenHint'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      case LessonType.text:
        final body = _textBody(lesson);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: body.isEmpty
              ? Text(
                  '—',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                )
              : Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF374151),
                        height: 1.5,
                      ),
                ),
        );
    }
  }
}
