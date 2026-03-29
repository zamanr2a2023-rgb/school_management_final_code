import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/lessons_repository.dart';
import 'package:high_school/domain/repositories/student_classes_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class _ClassDetailsLoaded {
  const _ClassDetailsLoaded({
    required this.cls,
    required this.lessons,
    required this.assignments,
  });
  final ClassEntity? cls;
  final List<LessonEntity> lessons;
  final List<AssignmentEntity> assignments;
}

Future<_ClassDetailsLoaded> _loadStudentClassDetails({
  required String classId,
  required ClassEntity? passedClass,
  required StudentClassesRepository studentClassesRepo,
  required ClassesRepository classesRepo,
  required LessonsRepository lessonsRepo,
  required AssignmentsRepository assignmentsRepo,
}) async {
  final detail = await studentClassesRepo.getStudentClassDetail(classId);
  if (detail != null) {
    return _ClassDetailsLoaded(
      cls: detail.classEntity,
      lessons: detail.lessons,
      assignments: detail.assignments,
    );
  }
  final cls = passedClass ?? await classesRepo.getClassById(classId);
  final lessons = await lessonsRepo.getLessons(classId: classId);
  final assignments = await assignmentsRepo.getAssignments(classId: classId);
  return _ClassDetailsLoaded(cls: cls, lessons: lessons, assignments: assignments);
}

class ClassDetailsScreen extends StatelessWidget {
  const ClassDetailsScreen({
    super.key,
    required this.classId,
    this.passedClass,
  });

  final String classId;

  /// When provided (e.g. navigated from classes list API), use this instead of fetching by id.
  final ClassEntity? passedClass;

  static Color _colorFromHex(String hex) {
    final s = hex.replaceFirst('#', '');
    return Color(int.parse('FF$s', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return FutureBuilder<_ClassDetailsLoaded>(
      future: _loadStudentClassDetails(
        classId: classId,
        passedClass: passedClass,
        studentClassesRepo: context.read<StudentClassesRepository>(),
        classesRepo: context.read<ClassesRepository>(),
        lessonsRepo: context.read<LessonsRepository>(),
        assignmentsRepo: context.read<AssignmentsRepository>(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final loaded = snapshot.data!;
        final cls = loaded.cls;
        final lessons = loaded.lessons;
        final assignments = loaded.assignments;
        if (cls == null) {
          return Center(child: Text(lang.t('classes.classNotFound')));
        }

        final primaryColor = _colorFromHex(cls.color);
        final primaryColorDark = primaryColor.withValues(alpha: 0.85);

        return Material(
          color: Colors.transparent,
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class header – gradient banner (compact)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, primaryColorDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cls.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cls.teacher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cls.schedule,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${cls.students} ${lang.t('classes.students')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tabs
                TabBar(
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: AppTheme.primary,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book, size: 18),
                          const SizedBox(width: 6),
                          Text(lang.t('lessons.lessons'),
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment, size: 18),
                          const SizedBox(width: 6),
                          Text(lang.t('assignments.assignments'),
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      _LessonsTab(lessons: lessons, lang: lang),
                      _AssignmentsTab(assignments: assignments, lang: lang),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LessonsTab extends StatelessWidget {
  const _LessonsTab({required this.lessons, required this.lang});

  final List<LessonEntity> lessons;
  final LanguageProvider lang;

  static IconData _iconForType(LessonType type) {
    switch (type) {
      case LessonType.video:
        return Icons.video_library;
      case LessonType.pdf:
        return Icons.picture_as_pdf;
      case LessonType.text:
        return Icons.description;
    }
  }

  static String _typeLabel(LessonType type) {
    switch (type) {
      case LessonType.video:
        return 'video';
      case LessonType.pdf:
        return 'pdf';
      case LessonType.text:
        return 'text';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book,
                  size: 48, color: AppTheme.primary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(lang.t('lessons.noLessonsAvailable'),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final l = lessons[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.push('/student/lessons/${l.id}'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_iconForType(l.type),
                          size: 22, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(l.description,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.calendar_today,
                                    size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(_formatDate(l.date),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ]),
                              if (l.duration != null && l.duration!.isNotEmpty)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.access_time,
                                      size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(l.duration!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600)),
                                ]),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(_typeLabel(l.type),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20,
                        color: AppTheme.primary.withValues(alpha: 0.8)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        final m = int.tryParse(parts[1]);
        final d = parts[2].length > 2 ? parts[2].substring(0, 2) : parts[2];
        if (m != null && m >= 1 && m <= 12) return '${months[m - 1]} $d';
      }
    } catch (_) {}
    return dateStr;
  }
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({required this.assignments, required this.lang});

  final List<AssignmentEntity> assignments;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment,
                  size: 48, color: AppTheme.primary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(lang.t('assignments.noAssignmentsAvailable'),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final a = assignments[index];
        Color statusColor = Colors.orange;
        if (a.status == AssignmentStatus.graded) statusColor = AppTheme.accent;
        if (a.status == AssignmentStatus.submitted) statusColor = Colors.grey;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.push('/student/assignments/${a.id}'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(a.description,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.calendar_today,
                                    size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                    '${lang.t('assignments.dueDate')} ${_formatDate(a.dueDate)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ]),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('${a.points} pts',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.amber.shade900)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(_statusLabel(a.status),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: statusColor,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                          if (a.grade != null) ...[
                            const SizedBox(height: 6),
                            Text(
                                '${lang.t('assignments.score')}: ${a.grade}/${a.points}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32))),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20,
                        color: AppTheme.primary.withValues(alpha: 0.8)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(AssignmentStatus s) {
    switch (s) {
      case AssignmentStatus.pending:
        return 'pending';
      case AssignmentStatus.submitted:
        return 'submitted';
      case AssignmentStatus.graded:
        return 'graded';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        final m = int.tryParse(parts[1]);
        final d = parts[2].length > 2 ? parts[2].substring(0, 2) : parts[2];
        if (m != null && m >= 1 && m <= 12) return '${months[m - 1]} $d';
      }
    } catch (_) {}
    return dateStr;
  }
}
