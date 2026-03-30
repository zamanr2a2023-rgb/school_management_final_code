import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/screens/teacher/teacher_pdf_attachment_screen.dart';

class TeacherAssignmentDetailsScreen extends StatefulWidget {
  const TeacherAssignmentDetailsScreen({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  State<TeacherAssignmentDetailsScreen> createState() => _TeacherAssignmentDetailsScreenState();
}

class _TeacherAssignmentDetailsScreenState extends State<TeacherAssignmentDetailsScreen> {
  Future<AssignmentEntity?>? _future;
  String? _futureForId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_futureForId != widget.assignmentId) {
      _futureForId = widget.assignmentId;
      _future = context.read<AssignmentsRepository>().getAssignmentById(widget.assignmentId);
    }
  }

  @override
  void didUpdateWidget(covariant TeacherAssignmentDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignmentId != widget.assignmentId) {
      _futureForId = widget.assignmentId;
      _future = context.read<AssignmentsRepository>().getAssignmentById(widget.assignmentId);
    }
  }

  String _formatDue(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatSubmitted(String iso) {
    if (iso.isEmpty || iso == '—') return iso;
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _isPdfAttachment(AssignmentAttachmentEntity att) {
    final mime = att.mimeType?.toLowerCase() ?? '';
    if (mime.contains('pdf')) return true;
    final u = att.url?.toLowerCase() ?? '';
    if (u.contains('.pdf')) return true;
    return att.originalName.toLowerCase().endsWith('.pdf');
  }

  void _openPdfViewer(BuildContext context, AssignmentAttachmentEntity att) {
    final url = att.url;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => TeacherPdfAttachmentScreen(
          url: url,
          fileName: att.originalName,
        ),
      ),
    );
  }

  /// True when [SubmissionEntity.id] is a real submission id (not a client fallback).
  static bool _submissionSupportsGrading(SubmissionEntity s) {
    final id = s.id.trim();
    if (id.isEmpty) return false;
    if (RegExp(r'_\d{4}-\d{2}-\d{2}').hasMatch(id)) return false;
    return true;
  }

  static String _gradingUnavailableHint(LanguageProvider lang) {
    final t = lang.t('assignments.gradingUnavailable');
    return (t == 'assignments.gradingUnavailable' || t.isEmpty)
        ? 'Cannot grade: submission id missing. Reload and try again.'
        : t;
  }

  Future<void> _reloadAssignment() async {
    if (!mounted) return;
    setState(() {
      _future = context.read<AssignmentsRepository>().getAssignmentById(widget.assignmentId);
    });
  }

  Future<void> _showEnterGradeDialog(
    BuildContext screenContext,
    LanguageProvider lang,
    AssignmentEntity assignment,
    SubmissionEntity submission,
  ) async {
    await showDialog<void>(
      context: screenContext,
      builder: (ctx) => _EnterGradeDialog(
        lang: lang,
        assignment: assignment,
        submission: submission,
        hostContext: screenContext,
        onSuccess: _reloadAssignment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return FutureBuilder<AssignmentEntity?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final a = snapshot.data;
        if (a == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                lang.t('assignments.noAssignmentsAvailable'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          );
        }

        final submissions = a.submissions ?? [];
        final attachments = a.attachments ?? [];
        final meta = <String>[];
        if (a.gradeLabel != null && a.gradeLabel!.isNotEmpty) meta.add(a.gradeLabel!);
        if (a.subjectName != null && a.subjectName!.isNotEmpty) meta.add(a.subjectName!);

        return Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            meta.join(' · '),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          a.description.isEmpty ? '—' : a.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.event, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${lang.t('assignments.dueDate')}: ${_formatDue(a.dueDate)}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.star_outline, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              '${lang.t('assignments.totalPoints')}: ${a.points}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.attach_file, size: 20, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                lang.t('assignments.attachments'),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...attachments.map((att) {
                            final canOpen = att.url != null && att.url!.isNotEmpty;
                            final isPdf = _isPdfAttachment(att);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
                                      color: isPdf ? Colors.red.shade700 : AppTheme.primary,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InkWell(
                                        onTap: !canOpen
                                            ? null
                                            : () {
                                                if (isPdf) {
                                                  _openPdfViewer(context, att);
                                                } else {
                                                  _openUrl(att.url!);
                                                }
                                              },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                att.originalName,
                                                style: const TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              if (att.size != null)
                                                Text(
                                                  '${(att.size! / 1024).toStringAsFixed(1)} KB',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (canOpen && isPdf) ...[
                                      IconButton(
                                        tooltip: lang.t('assignments.viewPdf'),
                                        icon: Icon(Icons.visibility_outlined, color: AppTheme.primary),
                                        onPressed: () => _openPdfViewer(context, att),
                                      ),
                                      IconButton(
                                        tooltip: lang.t('common.download'),
                                        icon: Icon(Icons.download_outlined, color: AppTheme.primary),
                                        onPressed: () => downloadTeacherPdfAttachment(
                                          context,
                                          att.url!,
                                          att.originalName,
                                        ),
                                      ),
                                    ] else if (canOpen)
                                      IconButton(
                                        tooltip: lang.t('common.view'),
                                        icon: Icon(Icons.open_in_new, size: 22, color: Colors.grey.shade600),
                                        onPressed: () => _openUrl(att.url!),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.assignment_turned_in, size: 22, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              lang.t('recent.recentSubmissions'),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (submissions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Text(
                            lang.t('assignments.noSubmission'),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: submissions.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, i) {
                            final s = submissions[i];
                            final st = (s.status ?? '').toLowerCase();
                            final isGraded = st == 'graded' || s.grade != null;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${lang.t('assignments.submittedOn')}: ${_formatSubmitted(s.submittedAt)}'),
                                  if (s.text != null && s.text!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        s.text!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isGraded
                                  ? Chip(
                                      label: Text(
                                        '${s.grade ?? '—'}/${a.points}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      backgroundColor: AppTheme.secondary.withValues(alpha: 0.2),
                                    )
                                  : _submissionSupportsGrading(s)
                                      ? OutlinedButton(
                                          onPressed: () => _showEnterGradeDialog(
                                            context,
                                            lang,
                                            a,
                                            s,
                                          ),
                                          child: Text(lang.t('assignments.enterGrade')),
                                        )
                                      : Tooltip(
                                          message: _gradingUnavailableHint(lang),
                                          child: OutlinedButton(
                                            onPressed: null,
                                            child: Text(lang.t('assignments.enterGrade')),
                                          ),
                                        ),
                            );
                          },
                        ),
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

/// Owns [TextEditingController]s for the grade form so they are disposed with the route,
/// not immediately after [showDialog] returns (avoids "used after being disposed").
class _EnterGradeDialog extends StatefulWidget {
  const _EnterGradeDialog({
    required this.lang,
    required this.assignment,
    required this.submission,
    required this.hostContext,
    required this.onSuccess,
  });

  final LanguageProvider lang;
  final AssignmentEntity assignment;
  final SubmissionEntity submission;
  final BuildContext hostContext;
  final Future<void> Function() onSuccess;

  @override
  State<_EnterGradeDialog> createState() => _EnterGradeDialogState();
}

class _EnterGradeDialogState extends State<_EnterGradeDialog> {
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _feedbackCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.submission;
    _scoreCtrl = TextEditingController(
      text: s.grade != null ? '${s.grade}' : '',
    );
    _feedbackCtrl = TextEditingController(text: s.feedback ?? '');
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = widget.lang;
    final assignment = widget.assignment;
    final submission = widget.submission;
    final host = widget.hostContext;

    final maxPts = assignment.points;
    final scoreParsed = int.tryParse(_scoreCtrl.text.trim());
    if (scoreParsed == null) {
      final m = lang.t('assignments.scoreInvalid');
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(
          content: Text(
            m == 'assignments.scoreInvalid' || m.isEmpty
                ? 'Enter a valid whole number for the score.'
                : m,
          ),
        ),
      );
      return;
    }
    if (scoreParsed < 0 || scoreParsed > maxPts) {
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(
          content: Text('Score must be between 0 and $maxPts.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    if (!host.mounted) return;
    final repo = host.read<AssignmentsRepository>();
    final result = await repo.gradeSubmission(
      submissionId: submission.id,
      score: scoreParsed,
      feedback: _feedbackCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.ok) {
      Navigator.of(context).pop();
      if (!host.mounted) return;
      final okMsg = lang.t('assignments.gradeSaved');
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(
          content: Text(
            okMsg == 'assignments.gradeSaved' || okMsg.isEmpty
                ? 'Grade saved successfully.'
                : okMsg,
          ),
        ),
      );
      if (host.mounted) await widget.onSuccess();
    } else {
      if (!host.mounted) return;
      final fail = lang.t('assignments.gradeSaveFailed');
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                (fail == 'assignments.gradeSaveFailed' || fail.isEmpty
                    ? 'Could not save the grade.'
                    : fail),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final assignment = widget.assignment;
    final submission = widget.submission;

    return AlertDialog(
      title: Text(lang.t('assignments.enterGrade')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              submission.studentName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              '${lang.t('assignments.score')} (0–${assignment.points})',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _scoreCtrl,
              enabled: !_submitting,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0–${assignment.points}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              lang.t('assignments.feedback'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _feedbackCtrl,
              enabled: !_submitting,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: lang.t('assignments.provideFeedback'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(lang.t('common.cancel')),
        ),
        if (_submitting)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: _submit,
            child: Text(lang.t('assignments.saveGrade')),
          ),
      ],
    );
  }
}
