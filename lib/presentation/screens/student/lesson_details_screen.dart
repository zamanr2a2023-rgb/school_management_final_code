import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/data/datasources/student_lesson_remote_datasource.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/entities/student_lesson_detail.dart';
import 'package:high_school/domain/repositories/lessons_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

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

  static String? _formatDate(String iso, String localeCode) {
    if (iso.trim().isEmpty) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat.yMMMd(localeCode).format(dt);
    } catch (_) {
      return null;
    }
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final locale = Localizations.localeOf(context).toLanguageTag();

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
        final dateStr = _formatDate(lesson.dateIso, locale);
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
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_outlined, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      lang.t('lessons.videoPlayerPlaceholder'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    if (primaryUrl != null && primaryUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _openUrl(primaryUrl),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade900,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(lang.t('lessons.openVideoLink'), style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      case LessonType.pdf:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                lang.t('lessons.pdfDocument'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                lang.t('lessons.pdfOpenHint'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (primaryUrl != null && primaryUrl.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openUrl(primaryUrl),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(lang.t('lessons.downloadPDF')),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(primaryUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(lang.t('lessons.viewPdf')),
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
