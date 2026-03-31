import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class LiveSessionDetailScreen extends StatelessWidget {
  const LiveSessionDetailScreen({
    super.key,
    required this.sessionId,
    this.passedSession,
  });

  final String sessionId;
  /// When provided (e.g. from dashboard), use this instead of looking up by sessionId in repo.
  final LiveSessionEntity? passedSession;

  static String _formatSessionDate(String dateStr) {
    try {
      final d = DateTime.tryParse(dateStr);
      if (d != null) return '${d.month}/${d.day}/${d.year}';
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final day = parts[2].length > 2 ? parts[2].substring(0, 2) : parts[2];
        final d = int.tryParse(day);
        if (m != null && d != null && y != null) return '$m/$d/$y';
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (passedSession != null) {
      final s = passedSession!;
      final platformStr =
          s.platform == LiveSessionPlatform.zoom ? 'Zoom' : 'Google Meet';
      final formattedDate = _formatSessionDate(s.date);
      final classDisplayName = s.classId.isNotEmpty ? s.classId : '-';
      return _buildContent(context, lang: lang, session: s,
          classDisplayName: classDisplayName, formattedDate: formattedDate,
          platformStr: platformStr);
    }

    return FutureBuilder(
      future: Future.wait([
        context.read<LiveSessionsRepository>().getLiveSessions(),
        context.read<ClassesRepository>().getClasses(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = (snapshot.data![0] as List).cast<LiveSessionEntity>();
        final classes = (snapshot.data![1] as List).cast<ClassEntity>();
        LiveSessionEntity? session;
        try {
          session = sessions.firstWhere((s) => s.id == sessionId);
        } catch (_) {
          session = null;
        }
        ClassEntity? classData;
        if (session != null) {
          try {
            classData = classes.firstWhere((c) => c.id == session!.classId);
          } catch (_) {}
        }

        if (session == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(lang.t('live.sessionNotFound')),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/student/live-sessions'),
                  child: Text(lang.t('common.back')),
                ),
              ],
            ),
          );
        }

        final s = session;
        final platformStr =
            s.platform == LiveSessionPlatform.zoom ? 'Zoom' : 'Google Meet';
        final formattedDate = _formatSessionDate(s.date);
        final classDisplayName = classData?.name ?? '-';
        return _buildContent(context, lang: lang, session: s,
            classDisplayName: classDisplayName, formattedDate: formattedDate,
            platformStr: platformStr);
      },
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required LanguageProvider lang,
    required LiveSessionEntity session,
    required String classDisplayName,
    required String formattedDate,
    required String platformStr,
  }) {
    final s = session;
    return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header – match React (primary blue)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.t('live.liveSessions'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Card – light green border, class details, date/time, platform, Ready to Join (green)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: AppTheme.accent.withValues(alpha: 0.4), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.06),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10)),
                      ),
                      child: Text(
                        s.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailRow(
                            label: lang.t('classes.classDetails').toUpperCase(),
                            value: classDisplayName,
                            accentColor: AppTheme.accent,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label:
                                '${lang.t('live.sessionDate')} & ${lang.t('live.sessionTime')}'
                                    .toUpperCase(),
                            value: '$formattedDate\n${s.time}',
                            accentColor: AppTheme.accent,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: lang.t('live.platform').toUpperCase(),
                            value: platformStr,
                            accentColor: AppTheme.accent,
                          ),
                          const SizedBox(height: 20),
                          // Ready to Join – green gradient box + white button with green border (match React/design)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.accent,
                                  AppTheme.accent.withValues(alpha: 0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.video_call,
                                    size: 48,
                                    color:
                                        Colors.white.withValues(alpha: 0.95)),
                                const SizedBox(height: 12),
                                Text(
                                  'Ready to Join?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Click the button below to join the live session',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final zoomLink = s.link.trim();
                                      if (zoomLink.isEmpty) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(lang
                                                    .t('live.meetingLink'))),
                                          );
                                        }
                                        return;
                                      }
                                      final uri = Uri.tryParse(zoomLink);
                                      if (uri == null) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(lang
                                                    .t('live.meetingLink'))),
                                          );
                                        }
                                        return;
                                      }
                                      try {
                                        final launched = await launchUrl(uri,
                                            mode: LaunchMode
                                                .externalApplication);
                                        if (!launched && context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(lang
                                                    .t('live.meetingLink'))),
                                          );
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(lang
                                                    .t('live.meetingLink'))),
                                          );
                                        }
                                      }
                                    },
                                    icon:
                                        const Icon(Icons.open_in_new, size: 18),
                                    label: Text(lang.t('live.joinSession')),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppTheme.accent,
                                      side: const BorderSide(
                                          color: AppTheme.accent, width: 2),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Session Guidelines – muted card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session Guidelines',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• Join 5 minutes before the session starts\n• Keep your microphone muted when not speaking\n• Use the chat for questions\n• Have your notebook ready',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.accentColor,
  });

  final String label;
  final String value;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}
