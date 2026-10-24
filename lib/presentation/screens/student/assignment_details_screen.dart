import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/core/utils/app_date_format.dart';
import 'package:high_school/domain/entities/assignment_detail_result.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/my_submission_status.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/student_assignment_details_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/screens/teacher/teacher_lesson_media_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_pdf_attachment_screen.dart';

class _AssignmentScreenData {
  const _AssignmentScreenData({
    required this.assignment,
    required this.classData,
    required this.apiResult,
    required this.mySubmission,
  });
  final AssignmentEntity? assignment;
  final ClassEntity? classData;
  final AssignmentDetailResult? apiResult;
  final MySubmissionStatus? mySubmission;
}

class AssignmentDetailsScreen extends StatefulWidget {
  const AssignmentDetailsScreen({
    super.key,
    required this.assignmentId,
    this.passedAssignment,
  });

  final String assignmentId;
  /// When provided (e.g. from dashboard API), use this instead of fetching by id.
  final AssignmentEntity? passedAssignment;

  @override
  State<AssignmentDetailsScreen> createState() => _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> {
  String _submissionText = '';
  String? _selectedFileName;
  String? _selectedFilePath;
  bool _submitting = false;

  /// Bump to force [FutureBuilder] to re-run the loader after a submit.
  int _reloadTick = 0;

  void _reload() {
    if (!mounted) return;
    setState(() {
      _reloadTick++;
      _submissionText = '';
      _selectedFileName = null;
      _selectedFilePath = null;
    });
  }

  static bool _isPdfFileName(String name) {
    return name.toLowerCase().trim().endsWith('.pdf');
  }

  Future<void> _pickPdf(BuildContext pickerContext, LanguageProvider lang) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
    );
    if (!pickerContext.mounted) return;
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final name = f.name;
    if (!_isPdfFileName(name)) {
      ScaffoldMessenger.of(pickerContext).showSnackBar(
        SnackBar(content: Text(lang.t('assignments.pdfOnlyError'))),
      );
      return;
    }
    final path = f.path;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(pickerContext).showSnackBar(
        SnackBar(content: Text(lang.t('assignments.pdfOnlyError'))),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _selectedFileName = name;
      _selectedFilePath = path;
    });
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

  Future<void> _openAttachmentUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _openAttachment(BuildContext context, AssignmentAttachmentEntity att) {
    final url = att.url;
    if (url == null || url.isEmpty) return;
    if (_isImageAttachment(att)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => TeacherLessonImageScreen(
            url: url,
            title: att.originalName,
          ),
        ),
      );
      return;
    }
    if (_isPdfAttachment(att)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => TeacherPdfAttachmentScreen(
            url: url,
            fileName: att.originalName,
          ),
        ),
      );
      return;
    }
    _openAttachmentUrl(url);
  }

  String _formatDateTime(String dateStr) {
    final formatted = AppDateFormat.dateTime(dateStr);
    return formatted.isEmpty ? dateStr : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final apiRepo = context.read<StudentAssignmentDetailsRepository>();
    final assignmentsRepo = context.read<AssignmentsRepository>();
    final classesRepo = context.read<ClassesRepository>();

    final future = _loadAssignmentDetail(
      assignmentId: widget.assignmentId,
      passedAssignment: widget.passedAssignment,
      apiRepo: apiRepo,
      assignmentsRepo: assignmentsRepo,
      classesRepo: classesRepo,
    );

    return FutureBuilder<_AssignmentScreenData>(
      key: ValueKey('assignment-${widget.assignmentId}-$_reloadTick'),
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.assignment == null) {
          return Center(child: Text(lang.t('classes.classNotFound')));
        }
        return _buildContent(
          context,
          lang: lang,
          a: data.assignment!,
          classData: data.classData,
          mySubmission: data.mySubmission,
        );
      },
    );
  }

  static Future<_AssignmentScreenData> _loadAssignmentDetail({
    required String assignmentId,
    required AssignmentEntity? passedAssignment,
    required StudentAssignmentDetailsRepository apiRepo,
    required AssignmentsRepository assignmentsRepo,
    required ClassesRepository classesRepo,
  }) async {
    // Load assignment detail + resubmit-aware "my submission" in parallel.
    final results = await Future.wait<Object?>([
      apiRepo.getAssignmentDetail(assignmentId),
      apiRepo.getMySubmission(assignmentId),
    ]);
    final apiResult = results[0] as AssignmentDetailResult?;
    final mySub = results[1] as MySubmissionStatus?;

    if (apiResult != null) {
      return _AssignmentScreenData(
        assignment: apiResult.assignment,
        classData: apiResult.classInfo,
        apiResult: apiResult,
        mySubmission: mySub,
      );
    }
    if (passedAssignment != null) {
      final classes = await classesRepo.getClasses();
      ClassEntity? classData;
      try {
        classData = classes.firstWhere((c) => c.id == passedAssignment.classId);
      } catch (_) {}
      return _AssignmentScreenData(
        assignment: passedAssignment,
        classData: classData,
        apiResult: null,
        mySubmission: mySub,
      );
    }
    final fallback = await Future.wait([
      assignmentsRepo.getAssignmentById(assignmentId),
      classesRepo.getClasses(),
    ]);
    final a = fallback[0] as AssignmentEntity?;
    final classes = fallback[1] as List<ClassEntity>;
    ClassEntity? classData;
    if (a != null) {
      try {
        classData = classes.firstWhere((c) => c.id == a.classId);
      } catch (_) {}
    }
    return _AssignmentScreenData(
      assignment: a,
      classData: classData,
      apiResult: null,
      mySubmission: mySub,
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required LanguageProvider lang,
    required AssignmentEntity a,
    ClassEntity? classData,
    MySubmissionStatus? mySubmission,
  }) {
    final daysUntilDue = _daysUntilDue(a.dueDate);
    final isOverdue = daysUntilDue < 0;
    final isUrgent = daysUntilDue <= 2 && daysUntilDue >= 0;

    // Prefer authoritative backend flags from MySubmissionStatus; fall back
    // to legacy assignment entity when the new endpoint isn't reachable.
    final ms = mySubmission;
    final hasSubmission = ms?.submission != null;
    final isGraded = ms?.isGraded ?? (a.status == AssignmentStatus.graded);
    final canResubmit = ms?.canResubmit ?? !hasSubmission;
    final isClosed = ms?.isClosed ?? false;
    final lateAllowed = ms?.lateAllowed ?? false;
    final pastDue = ms?.isPastDue ?? isOverdue;

    final currentStatus = isGraded
        ? AssignmentStatus.graded
        : (hasSubmission ? AssignmentStatus.submitted : a.status);
    final isPending = currentStatus == AssignmentStatus.pending;

    // Submit button: no submission yet AND can submit.
    final showSubmitButton = !hasSubmission && canResubmit && !isClosed;
    // Resubmit button: prior submission exists, not graded yet, can still resubmit.
    final showResubmitButton = hasSubmission &&
        !isGraded &&
        canResubmit &&
        !isClosed;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // ---- Status banners (priority order) ----
          if (isGraded)
            _buildGradedBanner(lang, a, mySubmission)
          else if (isClosed)
            _buildClosedBanner(lang)
          else if (pastDue && !lateAllowed && !hasSubmission)
            _buildDeadlinePassedBanner(lang)
          else if (pastDue && lateAllowed && !isGraded)
            _buildLateAllowedBanner(lang)
          else if (isOverdue && isPending)
            _buildAlert(context, lang, isOverdue: true, assignment: a)
          else if (isUrgent && isPending)
            _buildDueSoonAlert(context, lang, daysUntilDue)
          else if (hasSubmission && !isGraded)
            _buildSubmittedAlert(context, lang),

          const SizedBox(height: 12),
          _buildDetailsCard(context, lang, a, classData, currentStatus, isOverdue),

          if (isGraded && (a.grade != null || ms?.submission?.gradeScore != null)) ...[
            const SizedBox(height: 16),
            _buildGradeCard(context, lang, a, mySubmission),
          ],

          // Existing submission preview (when not graded yet)
          if (hasSubmission && !isGraded) ...[
            const SizedBox(height: 16),
            _buildYourSubmissionCard(context, lang, mySubmission: mySubmission),
          ],

          // Submit / Resubmit card
          if (showSubmitButton || showResubmitButton) ...[
            const SizedBox(height: 16),
            _buildSubmissionCard(
              context,
              lang,
              isResubmit: showResubmitButton,
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------- Banners ----------

  Widget _bannerBox({
    required Color bg,
    required Color border,
    required Color iconColor,
    required Color titleColor,
    required Color bodyColor,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: titleColor)),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: bodyColor)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradedBanner(LanguageProvider lang, AssignmentEntity a, MySubmissionStatus? ms) {
    final score = ms?.submission?.gradeScore ?? a.grade ?? 0;
    final feedback = ms?.submission?.gradeFeedback ?? a.feedback ?? '';
    final body = lang
        .t('assignments.submissionGradedBannerBody')
        .replaceAll('{score}', score.toString())
        .replaceAll('{points}', a.points.toString());
    String subtitle = body;
    if (feedback.trim().isNotEmpty) {
      final fb = lang
          .t('assignments.submissionGradedBannerFeedback')
          .replaceAll('{feedback}', feedback.trim());
      subtitle = '$body  ·  $fb';
    }
    return _bannerBox(
      bg: Colors.green.shade50,
      border: Colors.green.shade200,
      iconColor: Colors.green.shade700,
      titleColor: Colors.green.shade900,
      bodyColor: Colors.green.shade800,
      icon: Icons.verified_rounded,
      title: lang.t('assignments.submissionGradedBannerTitle'),
      subtitle: subtitle,
    );
  }

  Widget _buildClosedBanner(LanguageProvider lang) {
    return _bannerBox(
      bg: Colors.grey.shade100,
      border: Colors.grey.shade300,
      iconColor: Colors.grey.shade700,
      titleColor: Colors.grey.shade900,
      bodyColor: Colors.grey.shade700,
      icon: Icons.lock_outline_rounded,
      title: lang.t('assignments.assignmentClosedBanner'),
    );
  }

  Widget _buildDeadlinePassedBanner(LanguageProvider lang) {
    return _bannerBox(
      bg: Colors.red.shade50,
      border: Colors.red.shade200,
      iconColor: Colors.red.shade700,
      titleColor: Colors.red.shade900,
      bodyColor: Colors.red.shade800,
      icon: Icons.event_busy_rounded,
      title: lang.t('assignments.deadlinePassedBanner'),
    );
  }

  Widget _buildLateAllowedBanner(LanguageProvider lang) {
    return _bannerBox(
      bg: Colors.orange.shade50,
      border: Colors.orange.shade200,
      iconColor: Colors.orange.shade800,
      titleColor: Colors.orange.shade900,
      bodyColor: Colors.orange.shade800,
      icon: Icons.schedule_rounded,
      title: lang.t('assignments.lateSubmissionAllowedBanner'),
    );
  }

  Widget _buildAlert(BuildContext context, LanguageProvider lang, {required bool isOverdue, required AssignmentEntity assignment}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.t('assignments.overdue'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade800)),
                const SizedBox(height: 2),
                Text(
                  '${lang.t('assignments.dueDate')} ${_formatDateTime(assignment.dueDate)}. ${lang.t('assignments.lateSubmissionsNote')}',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueSoonAlert(BuildContext context, LanguageProvider lang, int daysUntilDue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.t('assignments.dueSoon'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900)),
                const SizedBox(height: 2),
                Text(
                  '${lang.t('assignments.dueDate')} $daysUntilDue ${daysUntilDue == 1 ? lang.t('assignments.day') : lang.t('assignments.days')}.',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedAlert(BuildContext context, LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.t('assignments.submitted'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade900)),
                const SizedBox(height: 2),
                Text(lang.t('assignments.submittedReceived'), style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, LanguageProvider lang, AssignmentEntity a, ClassEntity? classData, AssignmentStatus currentStatus, bool isOverdue) {
    Color statusColor = Colors.orange;
    if (currentStatus == AssignmentStatus.graded) statusColor = AppTheme.accent;
    if (currentStatus == AssignmentStatus.submitted) statusColor = AppTheme.primary;
    if (isOverdue && currentStatus == AssignmentStatus.pending) statusColor = Colors.red;

    String statusText = currentStatus.name;
    if (statusText == 'pending') statusText = lang.t('assignments.pending').split(' ').first;
    if (statusText == 'submitted') statusText = lang.t('assignments.submitted');
    if (statusText == 'graded') statusText = lang.t('assignments.graded');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.description, size: 20, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(a.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(a.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.t('assignments.classLabel'), style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(classData?.name ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.t('assignments.dueDate'), style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(_formatDateTime(a.dueDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang.t('assignments.points'), style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${a.points}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang.t('assignments.statusLabel'), style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            _buildAttachmentsSection(lang, a.attachments),
          ],
        ),
      ),
    );
  }

  bool _looksLike(String value, List<String> exts) {
    var lower = value.toLowerCase().trim();
    try {
      final path = Uri.parse(value).path;
      if (path.isNotEmpty) lower = path.toLowerCase();
    } catch (_) {}
    lower = lower.split('?').first.split('#').first;
    return exts.any(lower.endsWith);
  }

  bool _isImageAttachment(AssignmentAttachmentEntity att) {
    final mime = att.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return true;
    const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'];
    if (_looksLike(att.originalName, imageExts)) return true;
    final base = att.originalName.trim().toUpperCase();
    if (base.startsWith('IMG-') || base.startsWith('IMG_')) return true;
    final url = att.url;
    if (url == null) return false;
    if (_looksLike(url, imageExts)) return true;
    final u = url.toLowerCase();
    return u.contains('/image/') || u.contains('image/upload');
  }

  bool _isPdfAttachment(AssignmentAttachmentEntity att) {
    if (_isImageAttachment(att)) return false;
    final mime = att.mimeType?.toLowerCase() ?? '';
    if (mime.contains('pdf')) return true;
    final url = att.url;
    if (url != null && _looksLike(url, ['.pdf'])) return true;
    return att.originalName.toLowerCase().endsWith('.pdf');
  }

  Widget _buildAttachmentsSection(LanguageProvider lang, List<AssignmentAttachmentEntity>? attachments) {
    if (attachments == null || attachments.isEmpty) return const SizedBox.shrink();
    final items = attachments.where((a) => a.url != null && a.url!.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.folder_open_outlined, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              lang.t('assignments.attachments'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700, letterSpacing: 0.2),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((att) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAttachmentTile(lang, att),
            )),
      ],
    );
  }

  Widget _buildAttachmentTile(LanguageProvider lang, AssignmentAttachmentEntity att) {
    final isPdf = _isPdfAttachment(att);
    final isImage = _isImageAttachment(att);
    final iconColor = isPdf ? Colors.red.shade700 : AppTheme.primary;
    final iconBg = isPdf ? Colors.red.shade50 : AppTheme.primary.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openAttachment(context, att),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.06),
                Colors.white,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                    isPdf
                        ? Icons.picture_as_pdf_rounded
                        : isImage
                            ? Icons.image_rounded
                            : Icons.insert_drive_file_rounded,
                    size: 22,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        att.originalName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPdf ? lang.t('assignments.viewPdf') : lang.t('common.view'),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPdf || isImage ? Icons.visibility_outlined : Icons.open_in_new_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeCard(BuildContext context, LanguageProvider lang, AssignmentEntity a, [MySubmissionStatus? ms]) {
    final grade = ms?.submission?.gradeScore ?? a.grade ?? 0;
    final feedback = ms?.submission?.gradeFeedback ?? a.feedback;
    final pct = a.points > 0 ? (grade / a.points) * 100 : 0.0;
    final clampedPct = pct.clamp(0, 100).toDouble();

    Color accent;
    Color accentDark;
    String tierKey;
    IconData tierIcon;
    if (clampedPct >= 85) {
      accent = const Color(0xFF16A34A);
      accentDark = const Color(0xFF166534);
      tierKey = 'assignments.tierExcellent';
      tierIcon = Icons.emoji_events_rounded;
    } else if (clampedPct >= 70) {
      accent = const Color(0xFF22A06B);
      accentDark = const Color(0xFF15803D);
      tierKey = 'assignments.tierGreat';
      tierIcon = Icons.star_rounded;
    } else if (clampedPct >= 50) {
      accent = const Color(0xFFF59E0B);
      accentDark = const Color(0xFFB45309);
      tierKey = 'assignments.tierGood';
      tierIcon = Icons.thumb_up_alt_rounded;
    } else {
      accent = const Color(0xFFEF4444);
      accentDark = const Color(0xFFB91C1C);
      tierKey = 'assignments.tierKeepGoing';
      tierIcon = Icons.trending_up_rounded;
    }
    final tierLabel = lang.t(tierKey);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            accent.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.workspace_premium_rounded, size: 20, color: accentDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang.t('assignments.gradeAndFeedback'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: accentDark,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tierIcon, size: 12, color: accentDark),
                      const SizedBox(width: 4),
                      Text(
                        tierLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentDark,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _GradeCircle(
                  pct: clampedPct,
                  color: accent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$grade',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: accentDark,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '/${a.points}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${clampedPct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: accentDark,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              lang.t('assignments.score'),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: clampedPct / 100,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accent.withValues(alpha: 0.85), accentDark],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (pct < 100)
                        Text(
                          lang
                              .t('assignments.pointsToGo')
                              .replaceAll('{count}', '${a.points - grade}'),
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (feedback != null && feedback.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote_rounded, size: 16, color: accentDark),
                        const SizedBox(width: 6),
                        Text(
                          lang.t('assignments.teachersFeedback'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentDark,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feedback,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(
    BuildContext context,
    LanguageProvider lang, {
    bool isResubmit = false,
  }) {
    final canSubmit = _submissionText.trim().isNotEmpty || _selectedFileName != null;
    final headerTitle = isResubmit
        ? lang.t('assignments.resubmitAssignment')
        : lang.t('assignments.submitAssignment');
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3), width: 2)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.85)], begin: Alignment.centerLeft, end: Alignment.centerRight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isResubmit ? Icons.refresh_rounded : Icons.upload, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(headerTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(lang.t('assignments.uploadPdfHint'), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${lang.t('assignments.uploadFile')} (PDF)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (ctx) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
                                title: Text(lang.t('assignments.choosePdf')),
                                onTap: () async {
                                  Navigator.of(ctx).pop();
                                  await _pickPdf(context, lang);
                                },
                              ),
                              if (_selectedFileName != null)
                                ListTile(
                                  leading: const Icon(Icons.delete_outline),
                                  title: Text(lang.t('assignments.removeFile')),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    setState(() {
                                      _selectedFileName = null;
                                      _selectedFilePath = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.primary.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, size: 24, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(_selectedFileName != null ? lang.t('assignments.changeFile') : lang.t('assignments.chooseFile'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ),
                if (_selectedFileName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_selectedFileName!, style: TextStyle(fontSize: 12, color: Colors.blue.shade900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: Colors.blue.shade700),
                          onPressed: () => setState(() {
                            _selectedFileName = null;
                            _selectedFilePath = null;
                          }),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Center(child: Text(lang.t('assignments.or'), style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500))),
                const SizedBox(height: 16),
                Text(lang.t('assignments.writtenSubmission'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 6,
                  onChanged: (v) => setState(() => _submissionText = v),
                  decoration: InputDecoration(
                    hintText: lang.t('assignments.submissionResponseHint'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    lang.t('assignments.characterCount').replaceAll('{count}', '${_submissionText.length}'),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (canSubmit && !_submitting)
                        ? () => _handleSubmit(context, lang, isResubmit: isResubmit)
                        : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(isResubmit ? Icons.refresh_rounded : Icons.upload, size: 18),
                    label: Text(isResubmit
                        ? lang.t('assignments.resubmit')
                        : lang.t('assignments.submitAssignment')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  ),
                ),
                if (!canSubmit) ...[
                  const SizedBox(height: 8),
                  Center(child: Text(lang.t('assignments.pleaseAddFileOrResponse'), style: TextStyle(fontSize: 10, color: Colors.grey.shade500))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourSubmissionCard(BuildContext context, LanguageProvider lang, {MySubmissionStatus? mySubmission}) {
    final sub = mySubmission?.submission;
    String dateStr = '';
    String timeStr = '';
    String responseDisplay;
    bool isFile = false;

    if (sub != null) {
      final dt = sub.submittedAt;
      if (dt != null) {
        dateStr = AppDateFormat.date(dt);
        timeStr = AppDateFormat.time(dt);
      }
      if (sub.fileOriginalName != null && sub.fileOriginalName!.isNotEmpty) {
        responseDisplay = sub.fileOriginalName!;
        isFile = true;
      } else if (sub.textAnswer != null && sub.textAnswer!.trim().isNotEmpty) {
        responseDisplay = sub.textAnswer!;
      } else {
        responseDisplay = sub.submissionType == 'file' ? lang.t('assignments.fileSubmission') : '—';
        isFile = sub.submissionType == 'file';
      }
    } else {
      final now = DateTime.now();
      dateStr = AppDateFormat.date(now);
      timeStr = AppDateFormat.time(now);
      responseDisplay = _submissionText.isEmpty ? lang.t('assignments.fileSubmissionOnly') : _submissionText;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  lang.t('assignments.previousSubmission'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dateStr.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  timeStr.isEmpty
                      ? '${lang.t('assignments.submittedOn')} $dateStr'
                      : '${lang.t('assignments.submittedOn')} $dateStr at $timeStr',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(
                    isFile ? Icons.picture_as_pdf_rounded : Icons.short_text_rounded,
                    size: 18,
                    color: isFile ? Colors.red.shade700 : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      responseDisplay,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Submit / Resubmit handling ----------

  Future<void> _handleSubmit(
    BuildContext context,
    LanguageProvider lang, {
    required bool isResubmit,
  }) async {
    if (isResubmit) {
      final confirmed = await _confirmResubmit(context, lang);
      if (!confirmed) return;
    }
    if (!context.mounted) return;
    setState(() => _submitting = true);

    final repo = context.read<StudentAssignmentDetailsRepository>();
    final result = await repo.submitAssignment(
      widget.assignmentId,
      textAnswer: _submissionText.trim().isEmpty ? null : _submissionText.trim(),
      filePath: _selectedFilePath,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!context.mounted) return;

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('assignments.submitted'))),
      );
      _reload();
      return;
    }

    // Failure — pick a friendly message based on the categorised error.
    String snack;
    switch (result.errorKind) {
      case SubmitErrorKind.alreadyGraded:
        snack = lang.t('assignments.alreadyGradedToast');
        break;
      case SubmitErrorKind.assignmentClosed:
        snack = lang.t('assignments.assignmentClosedBanner');
        break;
      case SubmitErrorKind.lateNotAllowed:
        snack = lang.t('assignments.deadlinePassedBanner');
        break;
      default:
        final fail = lang.t('assignments.submitFailed');
        snack = result.message ??
            (fail == 'assignments.submitFailed' || fail.isEmpty
                ? 'Could not submit assignment.'
                : fail);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snack), backgroundColor: Colors.red.shade700),
    );

    // For non-recoverable backend states, refresh so the UI reflects new flags.
    if (result.errorKind == SubmitErrorKind.alreadyGraded ||
        result.errorKind == SubmitErrorKind.assignmentClosed ||
        result.errorKind == SubmitErrorKind.lateNotAllowed) {
      _reload();
    }
  }

  Future<bool> _confirmResubmit(BuildContext context, LanguageProvider lang) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('assignments.resubmitConfirmTitle')),
        content: Text(lang.t('assignments.resubmitConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.t('assignments.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(lang.t('assignments.replace')),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

/// Circular score badge with a thin progress ring used in the grade card.
class _GradeCircle extends StatelessWidget {
  const _GradeCircle({
    required this.pct,
    required this.color,
    required this.child,
  });

  final double pct;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 7,
              valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.12)),
            ),
          ),
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: pct / 100,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}
