import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/timetable_entity.dart';
import 'package:high_school/domain/entities/teacher_dashboard_entity.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/timetable_repository.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/domain/repositories/teacher_classes_repository.dart';
import 'package:high_school/domain/repositories/teacher_dashboard_repository.dart';
import 'package:high_school/presentation/screens/teacher/teacher_lesson_assignment_dialogs.dart';
import 'package:high_school/data/datasources/mock_data.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  static const List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final teacherId =
        auth.user?.id == 'demo_teacher' ? 'teacher1' : (auth.user?.id ?? 'teacher1');
    final now = DateTime.now();
    final bool isWeekday =
        now.weekday >= DateTime.monday && now.weekday <= DateTime.friday;
    final String today = isWeekday
        ? _weekdays[now.weekday - DateTime.monday]
        : '';

    return FutureBuilder<_TeacherDashboardData>(
      future: _loadDashboard(context, teacherId, today),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final firstName = auth.user?.name.split(' ').first ?? '';

        return Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeBanner(lang, firstName),
                const SizedBox(height: 16),
                _buildStatsGrid(context, lang, data.cardsMyClasses, data.cardsTotalStudents, data.cardsPendingGrading, data.cardsGraded),
                const SizedBox(height: 16),
                _buildQuickActions(context, lang, data.classesForActions),
                const SizedBox(height: 16),
                data.isFromApi
                    ? _buildTodaysClassesFromApi(context, lang, data.todaysClassesApi!, today)
                    : _buildTodaysClasses(context, lang, data.todaysClassesFallback!, data.classesForActions, today),
                const SizedBox(height: 16),
                data.isFromApi
                    ? _buildUpcomingSessionsFromApi(context, lang, data.upcomingSessionsApi!)
                    : _buildUpcomingSessions(context, lang, data.upcomingSessionsFallback!),
                const SizedBox(height: 16),
                data.isFromApi
                    ? _buildRecentSubmissionsFromApi(context, lang, data.recentSubmissionsApi!)
                    : _buildRecentSubmissions(context, lang),
                const SizedBox(height: 16),
                data.isFromApi
                    ? _buildMyClassesCardFromApi(context, lang, data.myClassesPreviewApi!)
                    : _buildMyClassesCard(context, lang, data.classesForActions),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_TeacherDashboardData> _loadDashboard(BuildContext context, String teacherId, String today) async {
    final dashboardRepo = context.read<TeacherDashboardRepository>();
    final api = await dashboardRepo.getDashboard();
    if (api != null) {
      final classesForActions = api.myClassesPreview
          .map((c) => ClassEntity(
                id: c.id,
                name: '${c.subject} - ${c.gradeLevel}',
                subject: c.subject,
                category: '',
                teacher: '',
                teacherId: '',
                students: c.studentsCount,
                color: '',
                schedule: '',
                room: '',
                level: c.gradeLevel,
                schoolYear: '',
              ))
          .toList();
      return _TeacherDashboardData.fromApi(api, classesForActions);
    }
    final classesRepo = context.read<ClassesRepository>();
    final timetableRepo = context.read<TimetableRepository>();
    final sessionsRepo = context.read<LiveSessionsRepository>();
    final myClasses = await classesRepo.getClassesByTeacher(teacherId);
    final timetableResult = await timetableRepo.getTimetable();
    final allSessions = await sessionsRepo.getLiveSessions();
    final now = DateTime.now();
    final todayClasses = today.isNotEmpty
        ? timetableResult.entries.where((e) => e.day == today).toList()
        : <TimetableEntryEntity>[];
    final twoDaysLater = now.add(const Duration(days: 2));
    final upcomingSessions = allSessions.where((s) {
      final d = DateTime.tryParse(s.date);
      return d != null && !d.isBefore(DateTime(now.year, now.month, now.day)) &&
          (d.isBefore(DateTime(twoDaysLater.year, twoDaysLater.month, twoDaysLater.day)) || d.isAtSameMomentAs(DateTime(twoDaysLater.year, twoDaysLater.month, twoDaysLater.day)));
    }).toList();
    final pendingGrading = MockData.submissions.where((s) => s.grade == null).length;
    final gradedCount = MockData.submissions.where((s) => s.grade != null).length;
    return _TeacherDashboardData.fromFallback(
      myClasses: myClasses,
      todayClasses: todayClasses,
      upcomingSessions: upcomingSessions,
      pendingGrading: pendingGrading,
      gradedCount: gradedCount,
    );
  }

  Widget _buildWelcomeBanner(LanguageProvider lang, String firstName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${lang.t('dashboard.welcomeBack')}, $firstName!', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text(lang.t('dashboard.teachingOverview'), style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, decoration: TextDecoration.none)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, LanguageProvider lang,
      int classesCount, int totalStudents, int pendingGrading, int gradedCount) {
    final stats = [
      (lang.t('classes.myClasses'), '$classesCount', Icons.menu_book, AppTheme.primary),
      (lang.t('classes.totalStudents'), '$totalStudents', Icons.people, AppTheme.secondary),
      (lang.t('assignments.pendingGrading'), '$pendingGrading', Icons.schedule, Colors.amber.shade700),
      (lang.t('assignments.graded'), '$gradedCount', Icons.check_circle, AppTheme.accent),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: stats.map((s) => _StatCard(title: s.$1, value: s.$2, icon: s.$3, color: s.$4)).toList(),
    );
  }

  Widget _buildQuickActions(
      BuildContext context, LanguageProvider lang, List<ClassEntity> myClasses) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Text(lang.t('actions.quickActions'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPickClassForQuickAction(
                        context, lang, myClasses, forLesson: true),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(lang.t('actions.createLesson')),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPickClassForQuickAction(
                        context, lang, myClasses, forLesson: false),
                    icon: const Icon(Icons.assignment, size: 18),
                    label: Text(lang.t('actions.createAssignment')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showScheduleLiveSessionDialog(context, lang, myClasses),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(lang.t('actions.scheduleSession')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysClasses(BuildContext context, LanguageProvider lang, List<TimetableEntryEntity> todayClasses, List<ClassEntity> myClasses, String today) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    today.isNotEmpty
                        ? '${lang.t('today.todayClasses')} - $today'
                        : lang.t('today.todayClasses'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: todayClasses.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(lang.t('today.noClasses'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))))
                : Column(
                    children: todayClasses.map((entry) {
                      ClassEntity? cls;
                      try {
                        cls = myClasses.firstWhere((c) => c.id == entry.classId);
                      } catch (_) {}
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => context.go('/teacher/classes/${entry.classId}'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(cls?.subject ?? entry.className, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3))),
                                      child: Text(cls?.level ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.secondary)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(children: [Icon(Icons.schedule, size: 14, color: Colors.grey.shade600), const SizedBox(width: 6), Text(entry.time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                                const SizedBox(height: 4),
                                Row(children: [Icon(Icons.people, size: 14, color: Colors.grey.shade600), const SizedBox(width: 6), Text('${cls?.students ?? 0} ${lang.t('classes.students')}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysClassesFromApi(BuildContext context, LanguageProvider lang, List<TeacherDashboardTodayClass> todaysClasses, String today) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    today.isNotEmpty ? '${lang.t('today.todayClasses')} - $today' : lang.t('today.todayClasses'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: todaysClasses.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(lang.t('today.noClasses'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))))
                : Column(
                    children: todaysClasses.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => context.go('/teacher/classes/${entry.classId}'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(entry.subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3))),
                                      child: Text(entry.gradeLevel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.secondary)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(children: [Icon(Icons.schedule, size: 14, color: Colors.grey.shade600), const SizedBox(width: 6), Text(entry.timeLabel.isNotEmpty ? entry.timeLabel : '—', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                                const SizedBox(height: 4),
                                Row(children: [Icon(Icons.people, size: 14, color: Colors.grey.shade600), const SizedBox(width: 6), Text('${entry.studentsCount} ${lang.t('classes.students')}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSessionsFromApi(BuildContext context, LanguageProvider lang, List<TeacherDashboardUpcomingSession> upcomingSessions) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Icon(Icons.video_call, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(lang.t('live.upcomingSessions'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: upcomingSessions.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No upcoming live sessions', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...upcomingSessions.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text('${s.date ?? ''} • ${s.time ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          )),
                      OutlinedButton(
                        onPressed: () => context.go('/teacher/live-sessions'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                        child: Text(lang.t('common.viewAll')),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSubmissionsFromApi(BuildContext context, LanguageProvider lang, List<TeacherDashboardRecentSubmission> recentSubmissions) {
    final pending = recentSubmissions.where((s) => !s.graded).toList();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Expanded(child: Text(lang.t('recent.recentSubmissions'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3))),
                  child: Text('${pending.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...pending.take(3).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.studentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_formatSubmittedDate(s.submittedAt ?? ''), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    )),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/teacher/classes'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                    child: Text(lang.t('actions.viewSubmissions')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyClassesCardFromApi(BuildContext context, LanguageProvider lang, List<TeacherDashboardClassPreview> myClassesPreview) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Expanded(child: Text(lang.t('classes.myClasses'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('${myClassesPreview.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...myClassesPreview.take(2).map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => context.go('/teacher/classes/${c.id}'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(c.subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3))),
                                    child: Text(c.gradeLevel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.secondary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(children: [Icon(Icons.people, size: 14, color: Colors.grey.shade600), const SizedBox(width: 6), Text('${c.studentsCount} ${lang.t('classes.students')}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                            ],
                          ),
                        ),
                      ),
                    )),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/teacher/classes'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                    child: Text(lang.t('common.viewAll')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPickClassForQuickAction(
    BuildContext context,
    LanguageProvider lang,
    List<ClassEntity> myClasses, {
    required bool forLesson,
  }) {
    if (myClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('classes.noClassesFound'))),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(lang.t('students.selectClass')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: myClasses.length,
            itemBuilder: (_, i) {
              final c = myClasses[i];
              final subtitle = '${c.subject} · ${c.level}';
              final titleText = c.name.trim().isNotEmpty ? c.name : subtitle;
              return ListTile(
                title: Text(titleText),
                subtitle: c.name.trim().isNotEmpty ? Text(subtitle) : null,
                onTap: () async {
                  Navigator.pop(dialogCtx);
                  final repo = context.read<TeacherClassesRepository>();
                  final full = await repo.getClassById(c.id);
                  if (!context.mounted) return;
                  if (full == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lang.t('classes.classNotFound'))),
                    );
                    return;
                  }
                  if (forLesson) {
                    showTeacherCreateLessonDialog(context, lang, full, null);
                  } else {
                    showTeacherCreateAssignmentDialog(context, lang, full);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(lang.t('common.cancel')),
          ),
        ],
      ),
    );
  }

  void _showScheduleLiveSessionDialog(BuildContext context, LanguageProvider lang,
      List<ClassEntity> myClasses) {
    const labelColor = Color(0xFF1F3C88);
    const borderColor = Color(0xFFD1D5DB);

    String title = '';
    String grade = '';
    String subject = '';
    String className = '';
    String date = '';
    String time = '';
    String zoomLink = '';
    String selectedClassId = myClasses.isNotEmpty ? myClasses.first.id : '';

    Widget dialogLabel(String text, {bool required = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: labelColor),
              children: [
                TextSpan(text: text),
                if (required)
                  const TextSpan(
                      text: ' *',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );

    InputDecoration inputDecoration(String hint,
            {Widget? prefixIcon, Widget? suffixIcon}) =>
        InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: borderColor)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
        );

    const gradeOptions = ['4th', '5th', '6th', '7th'];
    const subjectOptions = [
      'Mathematics',
      'Physics',
      'Chemistry',
      'SVT',
      'French',
      'Arabic',
      'English'
    ];

    void submit() {
      if (title.isEmpty || selectedClassId.isEmpty || date.isEmpty ||
          time.isEmpty || zoomLink.isEmpty) return;
      final platform = zoomLink.toLowerCase().contains('zoom')
          ? LiveSessionPlatform.zoom
          : LiveSessionPlatform.meet;
      final session = LiveSessionEntity(
        id: 'live-${DateTime.now().millisecondsSinceEpoch}',
        classId: selectedClassId,
        title: title,
        date: date,
        time: time,
        platform: platform,
        link: zoomLink,
        isActive: false,
      );
      context.read<LiveSessionsRepository>().addLiveSession(session);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(className.isEmpty
                ? lang.t('live.createSession')
                : '${lang.t('live.createSession')} — $className')));
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.sizeOf(ctx).width;
        final dialogWidth = (screenWidth > 420) ? 400.0 : (screenWidth - 24);
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lang.t('live.createLiveSession'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: labelColor),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close,
                              color: labelColor, size: 24),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            dialogLabel(lang.t('live.sessionTitle'),
                                required: true),
                            TextField(
                              decoration: inputDecoration(
                                  'e.g., Mathematics Q&A Session'),
                              onChanged: (v) => title = v,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      dialogLabel(lang.t('live.grade'),
                                          required: true),
                                      DropdownButtonFormField<String>(
                                        value: grade.isEmpty
                                            ? null
                                            : (gradeOptions.contains(grade)
                                                ? grade
                                                : null),
                                        decoration: inputDecoration(
                                                'Select grade')
                                            .copyWith(
                                                contentPadding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10)),
                                        isExpanded: true,
                                        items: gradeOptions
                                            .map((g) => DropdownMenuItem(
                                                value: g,
                                                child: Text('$g Grade')))
                                            .toList(),
                                        onChanged: (v) =>
                                            setDialogState(() => grade = v ?? ''),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      dialogLabel(lang.t('live.subject'),
                                          required: true),
                                      DropdownButtonFormField<String>(
                                        value: subject.isEmpty
                                            ? null
                                            : (subjectOptions.contains(subject)
                                                ? subject
                                                : null),
                                        decoration: inputDecoration(
                                                'Select subject')
                                            .copyWith(
                                                contentPadding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10)),
                                        isExpanded: true,
                                        items: subjectOptions
                                            .map((s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(s)))
                                            .toList(),
                                        onChanged: (v) => setDialogState(
                                            () => subject = v ?? ''),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            dialogLabel(lang.t('live.className'),
                                required: true),
                            if (myClasses.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value: selectedClassId.isEmpty
                                    ? null
                                    : selectedClassId,
                                decoration: inputDecoration(
                                        'e.g., 4th Grade - Math A')
                                    .copyWith(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10)),
                                isExpanded: true,
                                items: myClasses
                                    .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ))
                                    .toList(),
                                onChanged: (v) => setDialogState(
                                    () {
                                      selectedClassId = v ?? '';
                                      if (v != null) {
                                        final c = myClasses
                                            .firstWhere((x) => x.id == v);
                                        className = c.name;
                                      }
                                    }),
                              )
                            else
                              TextField(
                                decoration: inputDecoration(
                                    'e.g., 4th Grade - Math A'),
                                onChanged: (v) {
                                  className = v;
                                  selectedClassId = 'class1';
                                },
                              ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      dialogLabel(lang.t('live.date'),
                                          required: true),
                                      TextField(
                                        decoration: inputDecoration(
                                                'dd / mm / yyyy')
                                            .copyWith(
                                                prefixIcon: Icon(
                                                    Icons.calendar_today,
                                                    size: 20,
                                                    color:
                                                        Colors.grey.shade600)),
                                        onChanged: (v) => date = v,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      dialogLabel(lang.t('live.time'),
                                          required: true),
                                      TextField(
                                        decoration: inputDecoration('--:-- --')
                                            .copyWith(
                                                suffixIcon: Icon(
                                                    Icons.schedule,
                                                    size: 20,
                                                    color:
                                                        Colors.grey.shade600)),
                                        onChanged: (v) => time = v,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            dialogLabel(lang.t('live.zoomMeetingLink'),
                                required: true),
                            TextField(
                              decoration: inputDecoration(
                                  'https://zoom.us/j/...'),
                              onChanged: (v) => zoomLink = v,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            backgroundColor: Colors.white,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          child: Text(
                            lang.t('common.cancel'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          child: Text(
                            lang.t('live.createSession'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingSessions(BuildContext context, LanguageProvider lang, List<LiveSessionEntity> upcomingSessions) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Icon(Icons.video_call, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(lang.t('live.upcomingSessions'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: upcomingSessions.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No upcoming live sessions', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...upcomingSessions.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text('${s.date} • ${s.time}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          )),
                      OutlinedButton(
                        onPressed: () => context.go('/teacher/live-sessions'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                        child: Text(lang.t('common.viewAll')),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSubmissions(BuildContext context, LanguageProvider lang) {
    final pending = MockData.submissions.where((s) => s.grade == null).toList();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Expanded(child: Text(lang.t('recent.recentSubmissions'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3))),
                  child: Text('${pending.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...pending.take(3).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.studentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_formatSubmittedDate(s.submittedAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    )),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/teacher/classes'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                    child: Text(lang.t('actions.viewSubmissions')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyClassesCard(BuildContext context, LanguageProvider lang, List<ClassEntity> myClasses) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Expanded(child: Text(lang.t('classes.myClasses'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('${myClasses.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...myClasses.take(2).map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => context.go('/teacher/classes/${c.id}'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(c.subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3))),
                                    child: Text(c.level, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.secondary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(children: [Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600), const SizedBox(width: 6), Expanded(child: Text(c.schedule, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)))]),
                              const SizedBox(height: 4),
                              Row(children: [Icon(Icons.people, size: 14, color: Colors.grey.shade600), const SizedBox(width: 6), Text('${c.students} ${lang.t('classes.students')}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                            ],
                          ),
                        ),
                      ),
                    )),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/teacher/classes'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                    child: Text(lang.t('common.viewAll')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSubmittedDate(String iso) {
    try {
      final d = DateTime.tryParse(iso);
      if (d != null) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return 'Submitted ${months[d.month - 1]} ${d.day}';
      }
    } catch (_) {}
    return 'Submitted';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Holds either API dashboard data or fallback (classes + timetable + sessions).
class _TeacherDashboardData {
  _TeacherDashboardData({
    required this.isFromApi,
    required this.cardsMyClasses,
    required this.cardsTotalStudents,
    required this.cardsPendingGrading,
    required this.cardsGraded,
    required this.classesForActions,
    this.todaysClassesApi,
    this.todaysClassesFallback,
    this.upcomingSessionsApi,
    this.upcomingSessionsFallback,
    this.recentSubmissionsApi,
    this.myClassesPreviewApi,
  });

  final bool isFromApi;
  final int cardsMyClasses;
  final int cardsTotalStudents;
  final int cardsPendingGrading;
  final int cardsGraded;
  final List<ClassEntity> classesForActions;
  final List<TeacherDashboardTodayClass>? todaysClassesApi;
  final List<TimetableEntryEntity>? todaysClassesFallback;
  final List<TeacherDashboardUpcomingSession>? upcomingSessionsApi;
  final List<LiveSessionEntity>? upcomingSessionsFallback;
  final List<TeacherDashboardRecentSubmission>? recentSubmissionsApi;
  final List<TeacherDashboardClassPreview>? myClassesPreviewApi;

  factory _TeacherDashboardData.fromApi(TeacherDashboardEntity api, List<ClassEntity> classesForActions) {
    return _TeacherDashboardData(
      isFromApi: true,
      cardsMyClasses: api.cards.myClasses,
      cardsTotalStudents: api.cards.totalStudents,
      cardsPendingGrading: api.cards.pendingGrading,
      cardsGraded: api.cards.graded,
      classesForActions: classesForActions,
      todaysClassesApi: api.todaysClasses,
      upcomingSessionsApi: api.upcomingLiveSessions,
      recentSubmissionsApi: api.recentSubmissions,
      myClassesPreviewApi: api.myClassesPreview,
    );
  }

  factory _TeacherDashboardData.fromFallback({
    required List<ClassEntity> myClasses,
    required List<TimetableEntryEntity> todayClasses,
    required List<LiveSessionEntity> upcomingSessions,
    required int pendingGrading,
    required int gradedCount,
  }) {
    return _TeacherDashboardData(
      isFromApi: false,
      cardsMyClasses: myClasses.length,
      cardsTotalStudents: myClasses.fold<int>(0, (sum, c) => sum + c.students),
      cardsPendingGrading: pendingGrading,
      cardsGraded: gradedCount,
      classesForActions: myClasses,
      todaysClassesFallback: todayClasses,
      upcomingSessionsFallback: upcomingSessions,
    );
  }
}
