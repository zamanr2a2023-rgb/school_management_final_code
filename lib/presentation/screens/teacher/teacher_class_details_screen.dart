import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/data/datasources/assignments_remote_datasource.dart';
import 'package:high_school/data/datasources/lessons_remote_datasource.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/student_entity.dart';
import 'package:high_school/domain/entities/teacher_class_detail_result.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:high_school/domain/repositories/teacher_classes_repository.dart';
import 'package:high_school/domain/repositories/lessons_repository.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/domain/repositories/students_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/screens/teacher/teacher_lesson_assignment_dialogs.dart';

class TeacherClassDetailsScreen extends StatefulWidget {
  const TeacherClassDetailsScreen({super.key, required this.classId});

  final String classId;

  @override
  State<TeacherClassDetailsScreen> createState() => _TeacherClassDetailsScreenState();
}

class _TeacherClassDetailsScreenState extends State<TeacherClassDetailsScreen> {
  int _tabIndex = 0;
  int _refreshKey = 0;
  List<AssignmentEntity> _localAssignments = [];

  Future<Map<String, dynamic>> _loadData() async {
    final teacherClassesRepo = context.read<TeacherClassesRepository>();
    final lessonsRepo = context.read<LessonsRepository>();
    final assignmentsRepo = context.read<AssignmentsRepository>();
    final studentsRepo = context.read<StudentsRepository>();
    final liveRepo = context.read<LiveSessionsRepository>();

    final detail = await teacherClassesRepo.getClassDetailById(widget.classId);
    if (detail != null) {
      return {
        'class': detail.classEntity,
        'lessons': detail.lessons,
        'assignments': detail.assignments,
        'students': detail.students,
        'liveSessions': detail.liveSessions,
        'analytics': detail.analytics,
      };
    }

    final results = await Future.wait([
      teacherClassesRepo.getClassById(widget.classId),
      lessonsRepo.getLessons(classId: widget.classId),
      assignmentsRepo.getAssignments(classId: widget.classId),
      studentsRepo.getStudents(classId: widget.classId),
      liveRepo.getLiveSessions(),
    ]);

    final cls = results[0] as ClassEntity?;
    final lessons = (results[1] as List).cast<LessonEntity>();
    final assignments = (results[2] as List).cast<AssignmentEntity>();
    final students = (results[3] as List).cast<StudentEntity>();
    final allSessions = (results[4] as List).cast<LiveSessionEntity>();
    final liveSessions = allSessions.where((s) => s.classId == widget.classId).toList();

    return {
      'class': cls,
      'lessons': lessons,
      'assignments': assignments,
      'students': students,
      'liveSessions': liveSessions,
      'analytics': null as TeacherClassAnalytics?,
    };
  }

  static String _formatDate(String dateStr) {
    try {
      final d = DateTime.tryParse(dateStr);
      if (d != null) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[d.month - 1]} ${d.day}';
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(_refreshKey),
      future: _loadData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final cls = data['class'] as ClassEntity?;
        final lessons = data['lessons'] as List<LessonEntity>;
        final students = data['students'] as List<StudentEntity>;
        final liveSessions = data['liveSessions'] as List<LiveSessionEntity>;
        final apiAnalytics = data['analytics'] as TeacherClassAnalytics?;

        if (cls == null) {
          return Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(lang.t('classes.classNotFound')),
              ),
            ),
          );
        }

        // One-time init of local assignments from repo
        final repoAssignments = data['assignments'] as List<AssignmentEntity>;
        if (_localAssignments.isEmpty && repoAssignments.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _localAssignments = List.from(repoAssignments));
          });
        }
        final assignmentsToShow = _localAssignments.isNotEmpty ? _localAssignments : repoAssignments;

        return Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, lang, cls),
                const SizedBox(height: 16),
                _buildTabs(context, lang),
                const SizedBox(height: 12),
                IndexedStack(
                  index: _tabIndex,
                  children: [
                    _buildLessonsTab(context, lang, cls, lessons),
                    _buildAssignmentsTab(context, lang, cls, assignmentsToShow),
                    _buildStudentsTab(context, lang, students),
                    _buildLiveTab(context, lang, liveSessions),
                    _buildAnalyticsTab(context, lang, cls, lessons, assignmentsToShow, liveSessions, apiAnalytics),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, LanguageProvider lang, ClassEntity cls) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/teacher/classes'),
            icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
            label: Text(tr(lang, 'classes.backToClasses', 'Back to Classes'), style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          const SizedBox(height: 8),
          Text(cls.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(tr(lang, 'teacherClassDetails.manageSubtitle', 'Manage lessons, assignments, and students'), style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cls.schedule,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.people, size: 14, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Text('${cls.students} ${tr(lang, 'teacherClassDetails.studentsEnrolled', 'students enrolled')}', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String tr(LanguageProvider lang, String key, String fallback) {
    final s = lang.t(key);
    return (s == key || s.isEmpty) ? fallback : s;
  }

  Widget _buildTabs(BuildContext context, LanguageProvider lang) {
    final tabs = [
      (Icons.menu_book, tr(lang, 'lessons.lessons', 'Lessons')),
      (Icons.assignment, 'Assignments'),
      (Icons.people, tr(lang, 'classes.students', 'Students')),
      (Icons.video_call, 'Live'),
      (Icons.bar_chart, 'Analytics'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                      border: Border.all(color: selected ? AppTheme.primary : Colors.transparent, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(tabs[i].$1, size: 20, color: selected ? AppTheme.primary : Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tabs[i].$2,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: selected ? AppTheme.primary : Colors.grey.shade700),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLessonsTab(BuildContext context, LanguageProvider lang, ClassEntity cls, List<LessonEntity> lessons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${lessons.length} ${tr(lang, 'lessons.lessons', 'Lessons')}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            ElevatedButton.icon(
              onPressed: () => _showCreateLessonDialog(context, lang, cls, null),
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr(lang, 'teacherClassDetails.addLesson', 'Add Lesson')),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (lessons.isEmpty)
          _emptyCard(
            icon: Icons.menu_book,
            message: tr(lang, 'teacherClassDetails.noLessonsYet', 'No lessons created yet'),
          )
        else
          ...lessons.map((l) => _lessonCard(context, lang, cls, l)),
      ],
    );
  }

  Widget _lessonCard(BuildContext context, LanguageProvider lang, ClassEntity cls, LessonEntity lesson) {
    final typeStr = lesson.type == LessonType.video ? 'Video' : (lesson.type == LessonType.pdf ? 'PDF' : 'Text');
    final content = lesson.content.trim();
    final isUrl = content.startsWith('http://') || content.startsWith('https://');
    final fileName = _lessonFileNameFromContent(content);
    final showPdfRow = lesson.type == LessonType.pdf && content.isNotEmpty;
    final showLinkRow = content.isNotEmpty && !showPdfRow;
    final dateLabel = lesson.date.isNotEmpty ? _formatDate(lesson.date) : (lesson.lastUpdated.isNotEmpty ? _formatDate(lesson.lastUpdated) : '—');
    final updatedLabel = lesson.lastUpdated.isNotEmpty ? _formatDate(lesson.lastUpdated) : dateLabel;

    Future<void> openContent() async {
      if (!isUrl) return;
      try {
        await launchUrl(Uri.parse(content), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  lesson.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                _lessonOutlineChip(
                  label: lesson.status == LessonStatus.published ? tr(lang, 'teacherClassDetails.published', 'Published') : tr(lang, 'teacherClassDetails.draft', 'Draft'),
                  fg: lesson.status == LessonStatus.published ? const Color(0xFF2E7D32) : const Color(0xFF546E7A),
                  bg: lesson.status == LessonStatus.published ? const Color(0xFFE8F5E9) : const Color(0xFFECEFF1),
                  border: lesson.status == LessonStatus.published ? const Color(0xFFA5D6A7) : const Color(0xFFB0BEC5),
                  icon: lesson.status == LessonStatus.published ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                _lessonOutlineChip(
                  label: typeStr,
                  fg: const Color(0xFF37474F),
                  bg: const Color(0xFFECEFF1),
                  border: const Color(0xFFCFD8DC),
                ),
                if (cls.subject.isNotEmpty)
                  _lessonOutlineChip(
                    label: cls.subject,
                    fg: const Color(0xFFB8860B),
                    bg: const Color(0xFFFFF9E6),
                    border: const Color(0xFFFFE082),
                  ),
              ],
            ),
            if (lesson.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(lesson.description, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35), maxLines: 4, overflow: TextOverflow.ellipsis),
            ],
            if (showLinkRow) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: isUrl ? openContent : null,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isUrl ? _shortLinkDisplay(content) : content,
                        style: TextStyle(fontSize: 13, color: AppTheme.primary, decoration: isUrl ? TextDecoration.underline : TextDecoration.none),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showPdfRow) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: isUrl ? openContent : null,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fileName.isNotEmpty ? fileName : 'document.pdf',
                        style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600, decoration: isUrl ? TextDecoration.underline : TextDecoration.none),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (lesson.module != null && lesson.module!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.folder_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(child: Text(lesson.module!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                ],
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 15, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(dateLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_outlined, size: 15, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${tr(lang, 'common.update', 'Updated')} $updatedLabel',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => _toggleLessonPublishedStatus(context, lang, cls, lesson),
                      icon: Icon(lesson.status == LessonStatus.published ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppTheme.primary),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => _showCreateLessonDialog(context, lang, cls, lesson),
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => _confirmDeleteLesson(context, lang, lesson),
                      icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Eye icon: toggle published ↔ draft via PATCH /lesson/:id when API + class IDs are available.
  Future<void> _toggleLessonPublishedStatus(
    BuildContext context,
    LanguageProvider lang,
    ClassEntity cls,
    LessonEntity lesson,
  ) async {
    final newEntityStatus = lesson.status == LessonStatus.published ? LessonStatus.draft : LessonStatus.published;
    final apiStatusStr = newEntityStatus == LessonStatus.published ? 'published' : 'draft';
    final contentType = lesson.type == LessonType.video
        ? 'video'
        : (lesson.type == LessonType.pdf ? 'pdf' : 'text');
    final remote = context.read<LessonsRemoteDatasource>();
    final gid = cls.gradeId?.trim() ?? '';
    final sid = cls.subjectId?.trim() ?? '';
    final classId = lesson.classId.trim().isNotEmpty ? lesson.classId.trim() : cls.id;
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (remote.isConfigured && gid.isNotEmpty && sid.isNotEmpty && classId.isNotEmpty) {
      final ok = await remote.patchLesson(
        lessonId: lesson.id,
        title: lesson.title,
        description: lesson.description,
        contentType: contentType,
        chapter: lesson.module ?? '',
        status: apiStatusStr,
        gradeId: gid,
        subjectId: sid,
        classId: classId,
        date: lesson.date,
        filePath: null,
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _refreshKey++);
        messenger?.showSnackBar(SnackBar(content: Text(tr(lang, 'teacherClassDetails.statusUpdated', 'Status updated.'))));
      } else {
        messenger?.showSnackBar(const SnackBar(content: Text('Could not update status.')));
      }
      return;
    }

    if (remote.isConfigured && (gid.isEmpty || sid.isEmpty)) {
      messenger?.showSnackBar(const SnackBar(
        content: Text('Load class details from the server to change publish status.'),
      ));
      return;
    }

    context.read<LessonsRepository>().updateLesson(
      lesson.id,
      LessonEntity(
        id: lesson.id,
        classId: lesson.classId,
        title: lesson.title,
        description: lesson.description,
        type: lesson.type,
        content: lesson.content,
        date: lesson.date,
        duration: lesson.duration,
        status: newEntityStatus,
        lastUpdated: DateTime.now().toIso8601String().split('T').first,
        module: lesson.module,
      ),
    );
    setState(() => _refreshKey++);
  }

  Widget _lessonOutlineChip({
    required String label,
    required Color fg,
    required Color bg,
    required Color border,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static String _lessonFileNameFromContent(String content) {
    if (content.isEmpty) return '';
    try {
      final uri = Uri.tryParse(content);
      if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    } catch (_) {}
    if (content.contains('/')) {
      return content.split('/').last.split('?').first;
    }
    return content.length > 48 ? '${content.substring(0, 45)}…' : content;
  }

  static String _shortLinkDisplay(String url) {
    try {
      final u = Uri.parse(url);
      if (u.pathSegments.isNotEmpty) {
        final last = u.pathSegments.last;
        if (last.isNotEmpty) return last.length > 40 ? '${last.substring(0, 37)}…' : last;
      }
      if (u.host.isNotEmpty) return u.host.length > 36 ? '${u.host.substring(0, 33)}…' : u.host;
    } catch (_) {}
    return url.length > 42 ? '${url.substring(0, 39)}…' : url;
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  void _confirmDeleteLesson(BuildContext context, LanguageProvider lang, LessonEntity lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(lang, 'teacherClassDetails.deleteLesson', 'Delete Lesson')),
        content: Text('${tr(lang, 'common.confirm', 'Are you sure you want to delete')} "${lesson.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final remote = context.read<LessonsRemoteDatasource>();
              if (remote.isConfigured) {
                final ok = await remote.deleteLesson(lesson.id);
                if (!mounted) return;
                if (ok) {
                  setState(() => _refreshKey++);
                  messenger.showSnackBar(const SnackBar(content: Text('Lesson deleted.')));
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('Could not delete lesson. Try again.')));
                }
              } else {
                context.read<LessonsRepository>().deleteLesson(lesson.id);
                setState(() => _refreshKey++);
              }
            },
            child: Text(tr(lang, 'common.delete', 'Delete')),
          ),
        ],
      ),
    );
  }

  void _showCreateLessonDialog(BuildContext context, LanguageProvider lang, ClassEntity? cls, LessonEntity? editing) {
    showTeacherCreateLessonDialog(context, lang, cls, editing, onSuccess: () => setState(() => _refreshKey++));
  }

  Widget _buildAssignmentsTab(BuildContext context, LanguageProvider lang, ClassEntity cls, List<AssignmentEntity> assignments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${assignments.length} ${tr(lang, 'assignments.assignments', 'assignments')}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
            ),
            ElevatedButton.icon(
              onPressed: () => _showCreateAssignmentDialog(context, lang, cls),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: Text(tr(lang, 'teacherClassDetails.createAssignment', 'Create Assignment'), style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (assignments.isEmpty)
          _emptyCard(
            icon: Icons.assignment,
            message: tr(lang, 'teacherClassDetails.noAssignmentsYet', 'No assignments created yet'),
          )
        else
          ...assignments.map((a) => _assignmentCard(context, lang, cls, a)),
      ],
    );
  }

  Widget _assignmentCard(BuildContext context, LanguageProvider lang, ClassEntity cls, AssignmentEntity a) {
    final cardBorder = AppTheme.primary.withValues(alpha: 0.35);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    a.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary, height: 1.25),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Text(
                    '${a.points} pts',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            if (a.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                a.description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.45),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${tr(lang, 'assignments.dueDate', 'Due')}: ${_formatDate(a.dueDate)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/teacher/assignments/${a.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.45), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      tr(lang, 'teacherClassDetails.viewSubmissions', 'View Submissions'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: () => _showCreateAssignmentDialog(context, lang, cls, a),
                  icon: const Icon(Icons.edit_outlined, size: 22, color: AppTheme.primary),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: () => _confirmDeleteAssignment(context, lang, a),
                  icon: Icon(Icons.delete_outline_rounded, size: 22, color: Colors.red.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAssignment(BuildContext context, LanguageProvider lang, AssignmentEntity a) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(lang, 'teacherClassDetails.deleteAssignment', 'Delete Assignment')),
        content: Text('${tr(lang, 'common.confirm', 'Are you sure you want to delete')} "${a.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAssignment(context, a);
            },
            child: Text(tr(lang, 'common.delete', 'Delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAssignment(BuildContext context, AssignmentEntity a) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final remote = context.read<AssignmentsRemoteDatasource>();

    if (remote.isConfigured) {
      final ok = await remote.deleteAssignment(a.id);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _localAssignments.removeWhere((x) => x.id == a.id);
          _refreshKey++;
        });
        messenger?.showSnackBar(const SnackBar(content: Text('Assignment deleted.')));
      } else {
        messenger?.showSnackBar(const SnackBar(content: Text('Could not delete assignment. Try again.')));
      }
      return;
    }

    setState(() => _localAssignments.removeWhere((x) => x.id == a.id));
  }

  void _showCreateAssignmentDialog(BuildContext context, LanguageProvider lang, ClassEntity? cls, [AssignmentEntity? editing]) {
    showTeacherCreateAssignmentDialog(
      context,
      lang,
      cls,
      editing: editing,
      onResetAssignmentsFromServer: () => setState(() {
        _localAssignments.clear();
        _refreshKey++;
      }),
      onUpsertAssignment: (updated) => setState(() {
        final i = _localAssignments.indexWhere((x) => x.id == updated.id);
        if (i >= 0) _localAssignments[i] = updated;
        _refreshKey++;
      }),
      onAppendAssignmentLocal: (a) => setState(() => _localAssignments.add(a)),
    );
  }

  Widget _buildStudentsTab(BuildContext context, LanguageProvider lang, List<StudentEntity> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${students.length} ${tr(lang, 'teacherClassDetails.studentsEnrolled', 'students enrolled')}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        ...students.map((s) {
          final initials = (s.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()).toUpperCase();
          final subtitle = s.email.isEmpty ? '' : s.email;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
            child: ListTile(
              leading: (s.avatar != null && s.avatar!.isNotEmpty)
                  ? CircleAvatar(backgroundImage: NetworkImage(s.avatar!), onBackgroundImageError: (_, __) {})
                  : CircleAvatar(backgroundColor: AppTheme.primary.withValues(alpha: 0.15), child: Text(initials, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600))),
              title: Text(s.name),
              subtitle: subtitle.isEmpty ? null : Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              trailing: _badge('${s.grade}%', AppTheme.secondary),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLiveTab(BuildContext context, LanguageProvider lang, List<LiveSessionEntity> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${sessions.length} session${sessions.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          _emptyCard(
            icon: Icons.video_call,
            message: tr(lang, 'live.noUpcomingSessions', 'No live sessions scheduled'),
            subtitle: 'Schedule video calls with your students',
          )
        else
          ...sessions.map((s) {
            final platformStr = s.platform == LiveSessionPlatform.zoom ? 'Zoom' : 'Meet';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                        if (s.isActive) _badge('Live Now', Colors.red),
                        _badge(platformStr, Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [Icon(Icons.calendar_today, size: 12, color: AppTheme.primary), const SizedBox(width: 4), Text(_formatDate(s.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(width: 8), Icon(Icons.schedule, size: 12, color: AppTheme.primary), const SizedBox(width: 4), Text(s.time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async { try { await launchUrl(Uri.parse(s.link), mode: LaunchMode.externalApplication); } catch (_) {} },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(tr(lang, 'live.joinSession', 'Join Session')),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, LanguageProvider lang, ClassEntity cls, List<LessonEntity> lessons, List<AssignmentEntity> assignments, List<LiveSessionEntity> liveSessions, TeacherClassAnalytics? api) {
    final avgGrade = api != null ? api.avgGrade.round() : 87;
    final attendanceRate = api != null ? api.avgAttendance.round() : 95;
    const completionRate = 92;
    final totalStudents = api != null ? api.totalStudents : cls.students;
    final thirdLabel = api != null ? 'Lessons' : 'Completion';
    final thirdValue = api != null ? '${api.totalLessons}' : '$completionRate%';
    final thirdSubtitle = api != null ? 'Published in class' : '+5% from last month';
    final gradeSubtitle = api != null ? 'Class average' : '+3% from last month';
    final attendSubtitle = api != null ? 'Class average' : '+2% from last month';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _statCard('Avg. Grade', '$avgGrade%', Icons.trending_up, AppTheme.secondary, gradeSubtitle),
            _statCard('Attendance', '$attendanceRate%', Icons.people, AppTheme.primary, attendSubtitle),
            _statCard(thirdLabel, thirdValue, Icons.menu_book, AppTheme.accent, thirdSubtitle),
            _statCard('Students', '$totalStudents', Icons.emoji_events, AppTheme.primary, api != null ? 'From analytics' : 'Enrolled this semester'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, 'teacherClassDetails.contentOverview', 'Content Overview'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _overviewRow(Icons.menu_book, tr(lang, 'lessons.lessons', 'Lessons'), lessons.length),
                _overviewRow(Icons.assignment, tr(lang, 'assignments.assignments', 'Assignments'), assignments.length),
                _overviewRow(Icons.video_call, 'Live Sessions', liveSessions.length),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: AppTheme.primary.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 20, backgroundColor: AppTheme.primary.withValues(alpha: 0.15), child: Icon(Icons.bar_chart, color: AppTheme.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(lang, 'teacherClassDetails.performanceInsight', 'Performance Insight'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Your class is performing ${avgGrade >= 85 ? 'excellently' : 'well'} with an average grade of $avgGrade%. Keep up the great work!',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                CircleAvatar(radius: 16, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, size: 18, color: color)),
              ],
            ),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Row(children: [Icon(Icons.trending_up, size: 12, color: AppTheme.secondary), const SizedBox(width: 4), Expanded(child: Text(subtitle, style: TextStyle(fontSize: 10, color: AppTheme.secondary), overflow: TextOverflow.ellipsis))]),
          ],
        ),
      ),
    );
  }

  Widget _overviewRow(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon, size: 18, color: AppTheme.primary), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 14))]),
          _badge('$count', AppTheme.primary),
        ],
      ),
    );
  }

  Widget _emptyCard({required IconData icon, required String message, String? subtitle}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center)],
          ],
        ),
      ),
    );
  }
}
