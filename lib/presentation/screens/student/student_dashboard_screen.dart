import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/student_dashboard_entity.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/domain/repositories/student_dashboard_repository.dart';
import 'package:high_school/domain/repositories/subscription_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/providers/subscription_provider.dart';

LiveSessionEntity _liveSessionFromDashboardApi(
    StudentDashboardActiveSession s) {
  final link = s.zoomLink;
  final isZoom = link.toLowerCase().contains('zoom');
  return LiveSessionEntity(
    id: s.id,
    classId: s.subject,
    title: s.title,
    date: s.date,
    time: s.time,
    platform: isZoom ? LiveSessionPlatform.zoom : LiveSessionPlatform.meet,
    link: link,
    isActive: true,
  );
}

AssignmentEntity _assignmentFromDashboardApi(
    StudentDashboardUpcomingAssignment a) {
  AssignmentStatus status = AssignmentStatus.pending;
  if (a.myStatus == 'submitted') status = AssignmentStatus.submitted;
  if (a.myStatus == 'graded') status = AssignmentStatus.graded;
  return AssignmentEntity(
    id: a.id,
    classId: '',
    title: a.title,
    description: '',
    dueDate: a.dueAt,
    points: a.points,
    status: status,
    grade: null,
    feedback: null,
    submissions: null,
  );
}

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final subscription = context.watch<SubscriptionProvider>();

    return FutureBuilder<_DashboardData>(
      future: _loadDashboard(
        dashboardRepo: context.read<StudentDashboardRepository>(),
        classesRepo: context.read<ClassesRepository>(),
        assignmentsRepo: context.read<AssignmentsRepository>(),
        sessionsRepo: context.read<LiveSessionsRepository>(),
        subscriptionRepo: context.read<SubscriptionRepository>(),
        userId: auth.user?.id,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final firstName = auth.user?.name.split(' ').first ?? '';

        if (data.isFromApi) {
          return _buildContentFromApi(context,
              lang: lang, firstName: firstName, dashboard: data.api!);
        }

        final enrolledIds = data.enrolledIds ?? [];
        final enrolledClasses =
            data.classes!.where((c) => enrolledIds.contains(c.id)).toList();
        final pending = data.assignments!
            .where((a) => a.status == AssignmentStatus.pending)
            .length;
        final graded = data.assignments!
            .where((a) => a.status == AssignmentStatus.graded)
            .length;
        final activeSessions = data.sessions!.where((s) => s.isActive).toList();
        final upcomingAssignments = data.assignments!
            .where((a) => a.status == AssignmentStatus.pending)
            .take(3)
            .toList();

        return _buildContentFromMock(
          context,
          lang: lang,
          firstName: firstName,
          enrolledCount: enrolledClasses.length,
          pendingCount: pending,
          completedCount: graded,
          liveSessionsCount: activeSessions.length,
          activeSessions: activeSessions,
          upcomingAssignments: upcomingAssignments,
          classList: data.classes!,
        );
      },
    );
  }

  static Future<_DashboardData> _loadDashboard({
    required StudentDashboardRepository dashboardRepo,
    required ClassesRepository classesRepo,
    required AssignmentsRepository assignmentsRepo,
    required LiveSessionsRepository sessionsRepo,
    required SubscriptionRepository subscriptionRepo,
    String? userId,
  }) async {
    final dashboard = await dashboardRepo.getDashboard();
    if (dashboard != null) return _DashboardData.fromApi(dashboard);

    if (userId != null) {
      await subscriptionRepo.getSubscriptionForStudent(userId);
    }
    final results = await Future.wait([
      classesRepo.getClasses(),
      assignmentsRepo.getAssignments(),
      sessionsRepo.getLiveSessions(),
    ]);
    final classes =
        (results[0] as List<dynamic>).whereType<ClassEntity>().toList();
    final assignments = results[1] as List<AssignmentEntity>;
    final sessions =
        (results[2] as List<dynamic>).whereType<LiveSessionEntity>().toList();
    List<String> enrolledIds = [];
    if (userId != null) {
      final sub = await subscriptionRepo.getSubscriptionForStudent(userId);
      enrolledIds = sub?.enrolledClassIds ?? [];
    }
    return _DashboardData.fromFallback(
        classes, assignments, sessions, enrolledIds);
  }

  static Widget _buildContentFromApi(
    BuildContext context, {
    required LanguageProvider lang,
    required String firstName,
    required StudentDashboardEntity dashboard,
  }) {
    final cards = dashboard.cards;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(context, lang: lang, firstName: firstName),
          const SizedBox(height: 16),
          _buildStatsGrid(context,
              lang: lang,
              enrolledClasses: cards.enrolledClasses,
              pendingAssignments: cards.pendingAssignments,
              completed: cards.completed,
              liveSessions: cards.liveSessions),
          if (dashboard.activeLiveSessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildActiveSessionsCardFromApi(context,
                lang: lang, sessions: dashboard.activeLiveSessions),
          ],
          const SizedBox(height: 16),
          _buildUpcomingAssignmentsCardFromApi(context,
              lang: lang, assignments: dashboard.upcomingAssignments),
          const SizedBox(height: 16),
          _buildProgressOverviewCardFromApi(context,
              lang: lang, items: dashboard.progressOverview),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildWelcomeBanner(BuildContext context,
      {required LanguageProvider lang, required String firstName}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2A4A9E), Color(0xFF2F52B4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${lang.t('dashboard.welcomeBack')}, $firstName!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none)),
          const SizedBox(height: 6),
          Text(lang.t('dashboard.overview'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none)),
        ],
      ),
    );
  }

  static Widget _buildStatsGrid(BuildContext context,
      {required LanguageProvider lang,
      required int enrolledClasses,
      required int pendingAssignments,
      required int completed,
      required int liveSessions}) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.88,
      children: [
        _StatCard(
            title: lang.t('classes.myClasses'),
            value: enrolledClasses,
            icon: Icons.menu_book,
            iconBgColor: const Color(0xFFE0E7FA),
            iconColor: const Color(0xFF3F51B5)),
        _StatCard(
            title: lang.t('assignments.pending'),
            value: pendingAssignments,
            icon: Icons.assignment,
            iconBgColor: const Color(0xFFFFFBE6),
            iconColor: const Color(0xFFFFC107)),
        _StatCard(
            title: lang.t('lessons.completed'),
            value: completed,
            icon: Icons.check_circle,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF4CAF50)),
        _StatCard(
            title: lang.t('live.liveSessions'),
            value: liveSessions,
            icon: Icons.video_call,
            iconBgColor: const Color(0xFFE0E7FA),
            iconColor: const Color(0xFF3F51B5)),
      ],
    );
  }

  static Widget _buildActiveSessionsCardFromApi(BuildContext context,
      {required LanguageProvider lang,
      required List<StudentDashboardActiveSession> sessions}) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.video_call, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(lang.t('live.activeSessions'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primary))
            ]),
            const SizedBox(height: 12),
            ...sessions
                .take(3)
                .map((s) => _ActiveSessionTileFromApi(session: s, lang: lang)),
          ],
        ),
      ),
    );
  }

  static Widget _buildUpcomingAssignmentsCardFromApi(BuildContext context,
      {required LanguageProvider lang,
      required List<StudentDashboardUpcomingAssignment> assignments}) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(lang.t('assignments.upcomingAssignments'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold))),
                TextButton(
                    onPressed: () => context.go('/student/assignments'),
                    child: Text(lang.t('common.viewAll'),
                        style: const TextStyle(color: AppTheme.primary))),
              ],
            ),
            const SizedBox(height: 12),
            ...assignments.map((a) =>
                _UpcomingAssignmentTileFromApi(assignment: a, lang: lang)),
          ],
        ),
      ),
    );
  }

  static Widget _buildProgressOverviewCardFromApi(BuildContext context,
      {required LanguageProvider lang,
      required List<StudentDashboardProgressItem> items}) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.trending_up, size: 20, color: AppTheme.secondary),
              const SizedBox(width: 8),
              Text(lang.t('progress.progressOverview'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item.subject,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                            Text('${item.percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600))
                          ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: (item.percentage / 100).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primary),
                            minHeight: 6),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  static Widget _buildContentFromMock(
    BuildContext context, {
    required LanguageProvider lang,
    required String firstName,
    required int enrolledCount,
    required int pendingCount,
    required int completedCount,
    required int liveSessionsCount,
    required List<LiveSessionEntity> activeSessions,
    required List<AssignmentEntity> upcomingAssignments,
    required List<ClassEntity> classList,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(context, lang: lang, firstName: firstName),
          const SizedBox(height: 16),
          _buildStatsGrid(context,
              lang: lang,
              enrolledClasses: enrolledCount,
              pendingAssignments: pendingCount,
              completed: completedCount,
              liveSessions: liveSessionsCount),
          if (activeSessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildActiveSessionsCardFromMock(context,
                lang: lang, sessions: activeSessions),
          ],
          const SizedBox(height: 16),
          _buildUpcomingAssignmentsCardFromMock(context,
              lang: lang, assignments: upcomingAssignments),
          const SizedBox(height: 16),
          _buildProgressOverviewCardFromMock(context,
              lang: lang, classList: classList),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildActiveSessionsCardFromMock(BuildContext context,
      {required LanguageProvider lang,
      required List<LiveSessionEntity> sessions}) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.video_call, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(lang.t('live.activeSessions'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primary))
            ]),
            const SizedBox(height: 12),
            ...sessions.take(3).map((s) {
              final platformStr =
                  s.platform == LiveSessionPlatform.zoom ? 'Zoom' : 'Meet';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ]),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('${s.time} • $platformStr',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ]),
                    ),
                    ElevatedButton.icon(
                        onPressed: () => context.go(
                            '/student/live-sessions/${s.id}',
                            extra: s),
                        icon: const Icon(Icons.video_call, size: 16),
                        label: Text(lang.t('live.joinSession')),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static Widget _buildUpcomingAssignmentsCardFromMock(BuildContext context,
      {required LanguageProvider lang,
      required List<AssignmentEntity> assignments}) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(lang.t('assignments.upcomingAssignments'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold))),
                TextButton(
                    onPressed: () => context.go('/student/assignments'),
                    child: Text(lang.t('common.viewAll'),
                        style: const TextStyle(color: AppTheme.primary))),
              ],
            ),
            const SizedBox(height: 12),
            ...assignments
                .map((a) => _AssignmentCard(assignment: a, lang: lang)),
          ],
        ),
      ),
    );
  }

  static Widget _buildProgressOverviewCardFromMock(BuildContext context,
      {required LanguageProvider lang, required List<ClassEntity> classList}) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.trending_up, size: 20, color: AppTheme.secondary),
              const SizedBox(width: 8),
              Text(lang.t('progress.progressOverview'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 12),
            ...(classList.take(4).toList().asMap().entries.map((e) {
              final progress = 65.0 + e.key * 10;
              final cls = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cls.name,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                          Text('${progress.toInt()}%',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600))
                        ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primary),
                          minHeight: 6),
                    ),
                  ],
                ),
              );
            })),
          ],
        ),
      ),
    );
  }
}

class _DashboardData {
  _DashboardData._(
      {this.api,
      this.classes,
      this.assignments,
      this.sessions,
      this.enrolledIds});
  final StudentDashboardEntity? api;
  final List<ClassEntity>? classes;
  final List<AssignmentEntity>? assignments;
  final List<LiveSessionEntity>? sessions;
  final List<String>? enrolledIds;
  bool get isFromApi => api != null;
  factory _DashboardData.fromApi(StudentDashboardEntity dashboard) =>
      _DashboardData._(api: dashboard);
  factory _DashboardData.fromFallback(
          List<ClassEntity> classes,
          List<AssignmentEntity> assignments,
          List<LiveSessionEntity> sessions,
          List<String> enrolledIds) =>
      _DashboardData._(
          classes: classes,
          assignments: assignments,
          sessions: sessions,
          enrolledIds: enrolledIds);
}

class _ActiveSessionTileFromApi extends StatelessWidget {
  const _ActiveSessionTileFromApi({required this.session, required this.lang});
  final StudentDashboardActiveSession session;
  final LanguageProvider lang;
  @override
  Widget build(BuildContext context) {
    final platformStr = session.zoomLink.isNotEmpty ? 'Zoom' : 'Meet';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text('${session.time} • $platformStr',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: session.zoomLink.isNotEmpty
                ? () => context.go(
                    '/student/live-sessions/${session.id}',
                    extra: _liveSessionFromDashboardApi(session))
                : null,
            icon: const Icon(Icons.video_call, size: 16),
            label: Text(lang.t('live.joinSession')),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
        ],
      ),
    );
  }
}

class _UpcomingAssignmentTileFromApi extends StatelessWidget {
  const _UpcomingAssignmentTileFromApi(
      {required this.assignment, required this.lang});
  final StudentDashboardUpcomingAssignment assignment;
  final LanguageProvider lang;
  @override
  Widget build(BuildContext context) {
    final daysLeft = _daysUntilDue(assignment.dueAt);
    final isUrgent = daysLeft <= 2;
    final daysText =
        daysLeft >= 0 ? '${daysLeft}d left' : '${-daysLeft}d overdue';
    return InkWell(
      onTap: () => context.push(
          '/student/assignments/${assignment.id}',
          extra: _assignmentFromDashboardApi(assignment)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(daysText,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade700,
                            fontWeight: isUrgent ? FontWeight.w500 : null)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFFE65100)
                                  .withValues(alpha: 0.3))),
                      child: Text('${assignment.points} pts',
                          style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
            if (isUrgent)
              Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.warning_amber_rounded,
                      size: 20, color: Colors.red.shade700)),
          ],
        ),
      ),
    );
  }
}

int _daysUntilDue(String dueDateStr) {
  try {
    final d = DateTime.tryParse(dueDateStr);
    if (d == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(d.year, d.month, d.day);
    return due.difference(today).inDays;
  } catch (_) {
    return 0;
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignmentEntity assignment;
  final LanguageProvider lang;

  const _AssignmentCard({required this.assignment, required this.lang});

  @override
  Widget build(BuildContext context) {
    final daysLeft = _daysUntilDue(assignment.dueDate);
    final isUrgent = daysLeft <= 2;
    final daysText = daysLeft >= 0 ? '${daysLeft}d left' : '${-daysLeft}d left';

    return InkWell(
      onTap: () => context.push('/student/assignments/${assignment.id}', extra: assignment),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  assignment.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      daysText,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: isUrgent ? FontWeight.w500 : null),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color:
                                const Color(0xFFE65100).withValues(alpha: 0.3)),
                      ),
                      child: Text('${assignment.points} pts',
                          style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
            if (isUrgent)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.warning_amber_rounded,
                    size: 20, color: Colors.red.shade700),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.iconBgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3F51B5),
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
