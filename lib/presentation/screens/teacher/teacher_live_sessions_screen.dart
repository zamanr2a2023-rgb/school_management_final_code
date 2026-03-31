import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/teacher_live_sessions_overview.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/domain/repositories/teacher_classes_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/screens/teacher/teacher_live_session_create_dialog.dart';

// Reference colors from design: dark blue header, green for live cards, red for LIVE/delete
const Color _liveGreen = Color(0xFF4CAF50);
const Color _liveGreenMuted = Color(0xFF66BB6A);
const Color _liveRed = Color(0xFFE53935);
const Color _liveRedLight = Color(0xFFFFCDD2);
const Color _zoomBlueBg = Color(0xFFE3F2FD);
const Color _zoomBlueText = Color(0xFF2196F3);

class TeacherLiveSessionsScreen extends StatefulWidget {
  const TeacherLiveSessionsScreen({super.key});

  @override
  State<TeacherLiveSessionsScreen> createState() => _TeacherLiveSessionsScreenState();
}

class _TeacherLiveSessionsScreenState extends State<TeacherLiveSessionsScreen> {
  Future<({TeacherLiveSessionsOverview overview, List<ClassEntity> classes})>? _pageFuture;

  /// Bumped on each pull-to-refresh / reload so [FutureBuilder] gets a new element and
  /// subscribes to the new future (otherwise the UI can keep showing stale data).
  int _futureKey = 0;

  /// Last good payload; shown while a new request is in flight after refresh.
  ({TeacherLiveSessionsOverview overview, List<ClassEntity> classes})? _lastPageData;

  Future<({TeacherLiveSessionsOverview overview, List<ClassEntity> classes})> _loadPage() async {
    final live = context.read<LiveSessionsRepository>();
    final classesRepo = context.read<ClassesRepository>();
    final overview = await live.getTeacherSessionsOverview();
    final classes = await classesRepo.getClasses();
    return (overview: overview, classes: classes);
  }

  Future<void> _reload() async {
    final f = _loadPage();
    setState(() {
      _futureKey++;
      _pageFuture = f;
    });
    await f;
  }

  static String _formatDate(String dateStr) {
    try {
      final d = DateTime.tryParse(dateStr);
      if (d != null) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[d.month - 1]} ${d.day}, ${d.year}';
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    _pageFuture ??= _loadPage();

    return FutureBuilder<({TeacherLiveSessionsOverview overview, List<ClassEntity> classes})>(
      key: ValueKey<int>(_futureKey),
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _lastPageData = snapshot.data;
        }
        final data = snapshot.hasData
            ? snapshot.data!
            : (_lastPageData != null &&
                    (snapshot.connectionState == ConnectionState.waiting ||
                        snapshot.hasError)
                ? _lastPageData!
                : null);
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final overview = data.overview;
        final classes = data.classes;
        final liveSessions = overview.activeNow;
        final upcomingSessions = overview.upcoming;
        final completedSessions = overview.completed;

        ClassEntity? classFor(LiveSessionEntity s) {
          if (s.classId.isEmpty) return null;
          try {
            return classes.firstWhere((c) => c.id == s.classId);
          } catch (_) {
            return null;
          }
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, lang),
                  const SizedBox(height: 16),
                  if (liveSessions.isNotEmpty) ...[
                    _buildSectionTitle(context, lang.t('live.activeNow'), liveSessions.length, isLive: true),
                    const SizedBox(height: 8),
                    ...liveSessions.map(
                      (s) => _buildSessionCard(
                        context,
                        lang,
                        s,
                        classFor(s),
                        isLive: true,
                        isCompleted: false,
                        showDelete: !overview.fromRemote,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildSectionTitle(context, lang.t('live.upcomingSessions'), upcomingSessions.length, isLive: false),
                  const SizedBox(height: 8),
                  if (upcomingSessions.isEmpty)
                    _buildEmptyUpcoming(context, lang)
                  else
                    ...upcomingSessions.map(
                      (s) => _buildSessionCard(
                        context,
                        lang,
                        s,
                        classFor(s),
                        isLive: false,
                        isCompleted: false,
                        showDelete: !overview.fromRemote,
                      ),
                    ),
                  if (completedSessions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle(context, lang.t('live.completedSessions'), completedSessions.length, isLive: false),
                    const SizedBox(height: 8),
                    ...completedSessions.map(
                      (s) => _buildSessionCard(
                        context,
                        lang,
                        s,
                        classFor(s),
                        isLive: false,
                        isCompleted: true,
                        showDelete: false,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, LanguageProvider lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lang.t('live.liveSessions'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(lang.t('live.manageVirtualClasses'), style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, decoration: TextDecoration.none), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ElevatedButton.icon(
            onPressed: () => _showPickClassThenCreateLiveSession(context, lang),
            icon: const Icon(Icons.add, size: 18),
            label: Text(lang.t('live.create')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, int count, {required bool isLive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (isLive) ...[
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: _liveGreen, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text('$title ($count)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF424242)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildEmptyUpcoming(BuildContext context, LanguageProvider lang) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.video_call, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(lang.t('live.noUpcomingSessions'), style: TextStyle(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    LanguageProvider lang,
    LiveSessionEntity session,
    ClassEntity? cls, {
    required bool isLive,
    required bool isCompleted,
    required bool showDelete,
  }) {
    final headerColor = isLive
        ? _liveGreen
        : isCompleted
            ? Colors.grey.shade600
            : AppTheme.primary;
    final iconColor = isLive ? _liveGreenMuted : AppTheme.primary;
    final platformStr = session.platform == LiveSessionPlatform.zoom ? 'Zoom' : 'Google Meet';
    final hasApiMeta = session.gradeLevel != null ||
        session.subject != null ||
        (session.className != null && session.className!.isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: headerColor,
            child: Row(
              children: [
                const Icon(Icons.video_call, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(session.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(color: _liveRed, borderRadius: BorderRadius.all(Radius.circular(4))),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cls != null) ...[
                  Row(
                    children: [
                      Icon(Icons.school, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Flexible(child: Text(cls.level, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Icon(Icons.menu_book, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Expanded(child: Text(cls.subject, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Expanded(child: Text(cls.name, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else if (hasApiMeta) ...[
                  if (session.gradeLevel != null || session.subject != null)
                    Row(
                      children: [
                        if (session.gradeLevel != null) ...[
                          Icon(Icons.school, size: 14, color: iconColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              session.gradeLevel!,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (session.gradeLevel != null && session.subject != null) const SizedBox(width: 8),
                        if (session.subject != null) ...[
                          Icon(Icons.menu_book, size: 14, color: iconColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              session.subject!,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (session.className != null && session.className!.isNotEmpty) ...[
                    if (session.gradeLevel != null || session.subject != null) const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: iconColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            session.className!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: iconColor),
                    const SizedBox(width: 6),
                    Flexible(child: Text(_formatDate(session.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Icon(Icons.schedule, size: 14, color: iconColor),
                    const SizedBox(width: 6),
                    Flexible(child: Text(session.time, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis)),
                    if (session.durationMinutes != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '· ${session.durationMinutes} min',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _zoomBlueBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: _zoomBlueText.withValues(alpha: 0.3))),
                      child: Text(platformStr, style: const TextStyle(fontSize: 10, color: _zoomBlueText, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                if ((isLive && session.link.isNotEmpty) ||
                    (!isLive && !isCompleted && session.link.isNotEmpty) ||
                    showDelete) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (isLive && session.link.isNotEmpty) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchUrl(context, lang, session.link),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(lang.t('live.startSession')),
                            style: ElevatedButton.styleFrom(backgroundColor: _liveGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                          ),
                        ),
                        if (showDelete) const SizedBox(width: 8),
                      ] else if (!isLive && !isCompleted && session.link.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launchUrl(context, lang, session.link),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(lang.t('live.joinSession')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (showDelete) const SizedBox(width: 8),
                      ],
                      if (showDelete)
                        IconButton(
                          onPressed: () => _confirmDelete(context, lang, session.title),
                          icon: const Icon(Icons.delete_outline, size: 22, color: _liveRed),
                          style: IconButton.styleFrom(backgroundColor: _liveRedLight),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenLinkFailed(BuildContext context, LanguageProvider lang) {
    const k = 'live.openLinkFailed';
    final t = lang.t(k);
    final msg = (t == k || t.isEmpty)
        ? 'Could not open the meeting link. Check the URL or try again in a browser.'
        : t;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Opens Zoom/Meet/browser links. Does not rely on [canLaunchUrl] alone — on Android 11+
  /// it often returns false without manifest `<queries>`; we still try [launchUrl].
  Future<void> _launchUrl(
    BuildContext context,
    LanguageProvider lang,
    String raw,
  ) async {
    final s = raw.trim();
    if (s.isEmpty) {
      if (context.mounted) _showOpenLinkFailed(context, lang);
      return;
    }

    late final Uri uri;
    try {
      var parsed = Uri.parse(s);
      if (!parsed.hasScheme) {
        parsed = Uri.parse('https://$s');
      }
      uri = parsed;
    } catch (_) {
      if (context.mounted) _showOpenLinkFailed(context, lang);
      return;
    }

    if (!context.mounted) return;
    try {
      var launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && context.mounted) {
        _showOpenLinkFailed(context, lang);
      }
    } catch (_) {
      if (context.mounted) _showOpenLinkFailed(context, lang);
    }
  }

  Future<void> _showPickClassThenCreateLiveSession(
    BuildContext context,
    LanguageProvider lang,
  ) async {
    final auth = context.read<AuthProvider>();
    final teacherId =
        auth.user?.id == 'demo_teacher' ? 'teacher1' : auth.user?.id;
    final repo = context.read<TeacherClassesRepository>();
    final myClasses = await repo.getMyClasses(teacherId);
    if (!context.mounted) return;
    if (myClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('classes.noClassesFound'))),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
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
                  final full = await repo.getClassById(c.id);
                  if (!context.mounted) return;
                  if (full == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lang.t('classes.classNotFound'))),
                    );
                    return;
                  }
                  showTeacherCreateLiveSessionDialog(
                    context,
                    lang,
                    full,
                    onSuccess: () {
                      if (!mounted) return;
                      _reload();
                    },
                  );
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

  void _confirmDelete(BuildContext context, LanguageProvider lang, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(lang.t('common.cancel'))),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session "$title" has been deleted.')));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

}
