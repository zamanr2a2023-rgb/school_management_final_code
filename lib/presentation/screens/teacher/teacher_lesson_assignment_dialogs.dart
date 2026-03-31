import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:high_school/data/datasources/assignments_remote_datasource.dart';
import 'package:high_school/data/datasources/lessons_remote_datasource.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:high_school/domain/repositories/lessons_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/screens/teacher/teacher_dialog_date_time.dart';

String _tr(LanguageProvider lang, String key, String fallback) {
  final s = lang.t(key);
  return (s == key || s.isEmpty) ? fallback : s;
}

void showTeacherCreateLessonDialog(
  BuildContext hostContext,
  LanguageProvider lang,
  ClassEntity? cls,
  LessonEntity? editing, {
  VoidCallback? onSuccess,
}) {
  const labelColor = Color(0xFF1F3C88);
  const borderColor = Color(0xFFD1D5DB);
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

  String title = editing?.title ?? '';
  String description = editing?.description ?? '';
  String type = editing != null
      ? (editing.type == LessonType.video
          ? 'video'
          : (editing.type == LessonType.pdf ? 'pdf' : 'text'))
      : 'text';
  String module = editing?.module ?? '';
  String grade = '';
  String subject = 'Mathematics';
  if (cls != null) {
    final lv = cls.level
        .replaceAll(RegExp(r'\s*Grade\s*', caseSensitive: false), '')
        .trim();
    if (gradeOptions.contains(lv)) grade = lv;
    if (subjectOptions.contains(cls.subject)) subject = cls.subject;
  }
  String date = teacherFormatYmd(
      teacherParseYmd((editing?.date ?? '').trim()));
  String? attachedFilePath;
  String? attachedFileName;

  Widget dialogLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
      );

  InputDecoration inputDecoration(String hint) => InputDecoration(
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
      );

  showDialog(
    context: hostContext,
    builder: (dialogContext) {
      final screenWidth = MediaQuery.sizeOf(dialogContext).width;
      final dialogWidth = (screenWidth > 420) ? 400.0 : (screenWidth - 24);
      final submitting = <bool>[false];
      final lessonsRemote = dialogContext.read<LessonsRemoteDatasource>();
      final gidFromClass = cls?.gradeId?.trim() ?? '';
      final sidFromClass = cls?.subjectId?.trim() ?? '';
      final useApiCreate = editing == null &&
          cls != null &&
          lessonsRemote.isConfigured &&
          gidFromClass.isNotEmpty &&
          sidFromClass.isNotEmpty;
      final useApiEdit = editing != null &&
          cls != null &&
          lessonsRemote.isConfigured &&
          gidFromClass.isNotEmpty &&
          sidFromClass.isNotEmpty;
      final apiConfiguredMissingIds = editing == null &&
          cls != null &&
          lessonsRemote.isConfigured &&
          (gidFromClass.isEmpty || sidFromClass.isEmpty);
      final apiEditMissingIds = editing != null &&
          cls != null &&
          lessonsRemote.isConfigured &&
          (gidFromClass.isEmpty || sidFromClass.isEmpty);

      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submitLesson(LessonStatus status) async {
            if (cls == null && editing == null) return;
            if (submitting[0]) return;
            final messenger = ScaffoldMessenger.of(hostContext);
            final lessonType = type == 'video'
                ? LessonType.video
                : (type == 'pdf' ? LessonType.pdf : LessonType.text);
            final now = DateTime.now().toIso8601String().split('T').first;

            if (editing != null) {
              if (title.trim().isEmpty || module.trim().isEmpty) {
                messenger.showSnackBar(const SnackBar(
                    content: Text('Title and chapter are required.')));
                return;
              }
              final remote = hostContext.read<LessonsRemoteDatasource>();
              final gid = cls?.gradeId?.trim() ?? '';
              final sid = cls?.subjectId?.trim() ?? '';
              final classIdForApi = cls?.id ?? editing.classId;

              if (remote.isConfigured) {
                if (gid.isEmpty || sid.isEmpty) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text(
                          'This class has no gradeId or subjectId from the server. Reload class details while online, then try again.')));
                  return;
                }
                if (classIdForApi.isEmpty) {
                  messenger.showSnackBar(
                      const SnackBar(content: Text('Missing class id.')));
                  return;
                }
              }

              final useApi = remote.isConfigured &&
                  gid.isNotEmpty &&
                  sid.isNotEmpty &&
                  classIdForApi.isNotEmpty;
              final apiStatus =
                  status == LessonStatus.published ? 'published' : 'draft';
              final needsFile = type == 'pdf' || type == 'video';
              final hasNewFile =
                  attachedFilePath != null && attachedFilePath!.isNotEmpty;
              final hasExistingContent = editing.content.trim().isNotEmpty;

              if (useApi && needsFile && !hasNewFile && !hasExistingContent) {
                messenger.showSnackBar(const SnackBar(
                    content: Text('Attach a file for PDF or video lessons.')));
                return;
              }

              submitting[0] = true;
              setDialogState(() {});

              try {
                if (useApi) {
                  final ok = await remote.patchLesson(
                    lessonId: editing.id,
                    title: title.trim(),
                    description: description.trim(),
                    contentType: type,
                    chapter: module.trim(),
                    status: apiStatus,
                    gradeId: gid,
                    subjectId: sid,
                    classId: classIdForApi,
                    date: date.trim(),
                    filePath: hasNewFile ? attachedFilePath : null,
                  );
                  if (!hostContext.mounted) return;
                  if (ok) {
                    onSuccess?.call();
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                        const SnackBar(content: Text('Lesson updated.')));
                  } else {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Could not update lesson. Try again.')));
                  }
                  return;
                }

                hostContext.read<LessonsRepository>().updateLesson(
                    editing.id,
                    LessonEntity(
                      id: editing.id,
                      classId: editing.classId,
                      title: title,
                      description: description,
                      type: lessonType,
                      content: editing.content,
                      date: date,
                      duration: editing.duration,
                      status: status,
                      lastUpdated: now,
                      module: module.isEmpty ? null : module,
                    ));
                onSuccess?.call();
                if (ctx.mounted) Navigator.pop(ctx);
              } finally {
                submitting[0] = false;
                if (ctx.mounted) setDialogState(() {});
              }
              return;
            }

            if (cls == null) return;

            if (title.trim().isEmpty || module.trim().isEmpty) {
              messenger.showSnackBar(const SnackBar(
                  content: Text('Title and chapter are required.')));
              return;
            }

            final remote = hostContext.read<LessonsRemoteDatasource>();
            final gid = cls.gradeId?.trim() ?? '';
            final sid = cls.subjectId?.trim() ?? '';

            if (remote.isConfigured) {
              if (gid.isEmpty || sid.isEmpty) {
                messenger.showSnackBar(const SnackBar(
                    content: Text(
                        'This class has no gradeId or subjectId from the server. Reload class details while online, then try again.')));
                return;
              }
            }

            final useApi =
                remote.isConfigured && gid.isNotEmpty && sid.isNotEmpty;
            final apiStatus =
                status == LessonStatus.published ? 'published' : 'draft';

            final needsFile = type == 'pdf' || type == 'video';
            if (useApi &&
                needsFile &&
                (attachedFilePath == null || attachedFilePath!.isEmpty)) {
              messenger.showSnackBar(const SnackBar(
                  content: Text('Attach a file for PDF or video lessons.')));
              return;
            }

            submitting[0] = true;
            setDialogState(() {});

            try {
              if (useApi) {
                final ok = await remote.createLesson(
                  title: title.trim(),
                  description: description.trim(),
                  contentType: type,
                  chapter: module.trim(),
                  status: apiStatus,
                  gradeId: gid,
                  subjectId: sid,
                  classId: cls.id,
                  date: date.trim(),
                  filePath: attachedFilePath,
                );
                if (!hostContext.mounted) return;
                if (ok) {
                  onSuccess?.call();
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(SnackBar(
                      content: Text(apiStatus == 'published'
                          ? 'Lesson published.'
                          : 'Lesson saved as draft.')));
                } else {
                  messenger.showSnackBar(const SnackBar(
                      content: Text(
                          'Could not create lesson. Check network, file, and try again.')));
                }
                return;
              }

              hostContext.read<LessonsRepository>().addLesson(LessonEntity(
                    id: 'lesson-${DateTime.now().millisecondsSinceEpoch}',
                    classId: cls.id,
                    title: title,
                    description: description,
                    type: lessonType,
                    content: '',
                    date: date,
                    status: status,
                    lastUpdated: now,
                    module: module.isEmpty ? null : module,
                  ));
              onSuccess?.call();
              if (ctx.mounted) Navigator.pop(ctx);
            } finally {
              submitting[0] = false;
              if (ctx.mounted) setDialogState(() {});
            }
          }

          final mq = MediaQuery.of(ctx);
          final keyboardInset = mq.viewInsets.bottom;
          // Full area above keyboard; one scroll view for header + fields + actions so nothing is squeezed.
          final maxDialogHeight =
              (mq.size.height - keyboardInset - mq.padding.vertical - 48)
                  .clamp(220.0, mq.size.height);

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: dialogWidth, maxHeight: maxDialogHeight),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              editing != null
                                  ? _tr(lang, 'teacherClassDetails.editLesson',
                                      'Edit Lesson')
                                  : _tr(
                                      lang,
                                      'teacherClassDetails.createLesson',
                                      'Create New Lesson'),
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
                      const SizedBox(height: 12),
                      dialogLabel('${_tr(lang, 'teacherClassDetails.lessonTitle',
                              'Lesson Title')} *'),
                      TextField(
                          decoration:
                              inputDecoration('e.g., Introduction to Algebra'),
                          onChanged: (v) => title = v,
                          controller: TextEditingController(text: title)),
                      const SizedBox(height: 12),
                      dialogLabel(
                          _tr(lang, 'lessons.description', 'Description')),
                      TextField(
                          decoration:
                              inputDecoration('Describe the lesson content...'),
                          maxLines: 3,
                          onChanged: (v) => description = v,
                          controller: TextEditingController(text: description)),
                      const SizedBox(height: 12),
                      dialogLabel('${_tr(lang, 'teacherClassDetails.contentType',
                              'Content Type')} *'),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: inputDecoration('').copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10)),
                        items: ['text', 'pdf', 'video']
                            .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e == 'text' ? 'Text / PDF' : e)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => type = v ?? 'text'),
                      ),
                      const SizedBox(height: 12),
                      dialogLabel(
                          '${_tr(lang, 'teacherClassDetails.chapter', 'Chapter')} *'),
                      TextField(
                          decoration:
                              inputDecoration('e.g., Chapter 3: Equations'),
                          onChanged: (v) => module = v,
                          controller: TextEditingController(text: module)),
                      const SizedBox(height: 12),
                      if (apiConfiguredMissingIds || apiEditMissingIds) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            'This class has no gradeId or subjectId from the server. Reload class details while online, then try again.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange.shade900),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (cls != null && (useApiCreate || useApiEdit)) ...[
                        dialogLabel(_tr(lang,
                            'teacherClassDetails.classFromServer', 'Class')),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF3F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${cls.subject} · ${cls.level}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: labelColor,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'classId, gradeId, and subjectId are sent with create/update requests.',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ] else if (!(useApiCreate || useApiEdit)) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    dialogLabel(
                                        '${_tr(lang, 'live.grade', 'Grade')} *'),
                                    DropdownButtonFormField<String>(
                                      initialValue: grade.isEmpty
                                          ? null
                                          : (gradeOptions.contains(grade)
                                              ? grade
                                              : null),
                                      decoration: inputDecoration(
                                              'Select grade')
                                          .copyWith(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
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
                                  ]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    dialogLabel(
                                        '${_tr(lang, 'live.subject', 'Subject')} *'),
                                    DropdownButtonFormField<String>(
                                      initialValue: subject,
                                      decoration: inputDecoration('').copyWith(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10)),
                                      isExpanded: true,
                                      items: subjectOptions
                                          .map((s) => DropdownMenuItem(
                                              value: s, child: Text(s)))
                                          .toList(),
                                      onChanged: (v) => setDialogState(
                                          () => subject = v ?? 'Mathematics'),
                                    ),
                                  ]),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      dialogLabel('${_tr(lang, 'live.date', 'Date')} *'),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: teacherParseYmd(date),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              date = teacherFormatYmd(picked);
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: inputDecoration(
                            _tr(lang, 'teacherClassDetails.tapToPickDate',
                                'Tap to choose date'),
                          ).copyWith(
                            prefixIcon: Icon(Icons.calendar_today,
                                size: 20, color: Colors.grey.shade600),
                          ),
                          child: Text(
                            date,
                            style: const TextStyle(
                                fontSize: 14, color: labelColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      dialogLabel(_tr(lang, 'teacherClassDetails.attachFiles',
                          'Attach Files')),
                      Text(
                        editing != null
                            ? 'Optional for text; required for PDF/video if there is no existing file. Upload to replace the current file.'
                            : 'Optional for text lessons; required for PDF or video.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final r = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const [
                              'pdf',
                              'mp4',
                              'mov',
                              'webm',
                              'png',
                              'jpg',
                              'jpeg'
                            ],
                          );
                          if (r != null && r.files.isNotEmpty) {
                            final f = r.files.single;
                            final path = f.path;
                            if (path != null && path.isNotEmpty) {
                              setDialogState(() {
                                attachedFilePath = path;
                                attachedFileName = f.name;
                              });
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.upload_file,
                                  size: 36, color: labelColor),
                              const SizedBox(height: 8),
                              Text(
                                attachedFileName ??
                                    'Click to upload PDF or documents',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: (attachedFileName ?? '').isEmpty
                                        ? Colors.grey.shade600
                                        : labelColor),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed:
                                submitting[0] ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: labelColor,
                                side:
                                    const BorderSide(color: Color(0xFF90CAF9)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10)),
                            child: Text(_tr(lang, 'common.cancel', 'Cancel'),
                                style: const TextStyle(fontSize: 13)),
                          ),
                          if (editing != null)
                            FilledButton(
                              onPressed: (submitting[0] || apiEditMissingIds)
                                  ? null
                                  : () => submitLesson(editing.status),
                              style: FilledButton.styleFrom(
                                  backgroundColor: labelColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10)),
                              child: submitting[0]
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(
                                      _tr(
                                          lang,
                                          'teacherClassDetails.updateLesson',
                                          'Update Lesson'),
                                      style: const TextStyle(fontSize: 13)),
                            )
                          else ...[
                            OutlinedButton(
                              onPressed:
                                  (submitting[0] || apiConfiguredMissingIds)
                                      ? null
                                      : () => submitLesson(LessonStatus.draft),
                              style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade400),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10)),
                              child: Text(
                                  _tr(lang, 'teacherClassDetails.saveAsDraft',
                                      'Save as Draft'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            FilledButton(
                              onPressed: (submitting[0] ||
                                      apiConfiguredMissingIds)
                                  ? null
                                  : () => submitLesson(LessonStatus.published),
                              style: FilledButton.styleFrom(
                                  backgroundColor: labelColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10)),
                              child: submitting[0]
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(
                                      useApiCreate
                                          ? _tr(
                                              lang,
                                              'teacherClassDetails.publishLesson',
                                              'Publish')
                                          : _tr(
                                              lang,
                                              'teacherClassDetails.createLesson',
                                              'Create Lesson'),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// [onResetAssignmentsFromServer]: e.g. clear local list + bump refresh (after create API).
/// [onUpsertAssignment]: replace one assignment in local list + refresh (after edit).
/// [onAppendAssignmentLocal]: add one assignment offline (when not using API).
void showTeacherCreateAssignmentDialog(
  BuildContext hostContext,
  LanguageProvider lang,
  ClassEntity? cls, {
  AssignmentEntity? editing,
  VoidCallback? onResetAssignmentsFromServer,
  void Function(AssignmentEntity updated)? onUpsertAssignment,
  void Function(AssignmentEntity created)? onAppendAssignmentLocal,
}) {
  const labelColor = Color(0xFF1F3C88);
  const borderColor = Color(0xFFD1D5DB);

  String title = editing?.title ?? '';
  String description = editing?.description ?? '';
  final dueInit = teacherAssignmentInitialDue(editing?.dueDate);
  String dueDate = dueInit[0];
  String dueTime = dueInit[1];
  String points = editing?.points.toString() ?? '';
  String? attachedFileName;
  String? attachedFilePath;

  Widget dialogLabel(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
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

  showDialog(
    context: hostContext,
    builder: (ctx) {
      final screenWidth = MediaQuery.sizeOf(ctx).width;
      final dialogWidth = (screenWidth > 420) ? 400.0 : (screenWidth - 24);
      final assignmentsRemote = ctx.read<AssignmentsRemoteDatasource>();
      final gidFromClass = cls?.gradeId?.trim() ?? '';
      final sidFromClass = cls?.subjectId?.trim() ?? '';
      final useApiCreate = editing == null &&
          cls != null &&
          assignmentsRemote.isConfigured &&
          gidFromClass.isNotEmpty &&
          sidFromClass.isNotEmpty;
      final apiCreateMissingIds = editing == null &&
          cls != null &&
          assignmentsRemote.isConfigured &&
          (gidFromClass.isEmpty || sidFromClass.isEmpty);
      final submitting = <bool>[false];

      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (submitting[0]) return;
            final pts = int.tryParse(points) ?? 0;
            final messenger = ScaffoldMessenger.of(hostContext);

            if (editing != null) {
              if (title.trim().isEmpty || dueDate.trim().isEmpty) {
                messenger.showSnackBar(const SnackBar(
                    content: Text('Title and due date are required.')));
                return;
              }
              final remote = hostContext.read<AssignmentsRemoteDatasource>();
              if (remote.isConfigured) {
                submitting[0] = true;
                setDialogState(() {});
                try {
                  final timeStr =
                      dueTime.trim().isEmpty ? '23:59' : dueTime.trim();
                  final gid = cls?.gradeId?.trim() ?? '';
                  final sid = cls?.subjectId?.trim() ?? '';
                  final ok = await remote.patchAssignment(
                    assignmentId: editing.id,
                    title: title.trim(),
                    description: description.trim(),
                    dueDate: dueDate.trim(),
                    dueTime: timeStr,
                    points: '$pts',
                    gradeId: gid.isEmpty ? null : gid,
                    subjectId: sid.isEmpty ? null : sid,
                    classId: (cls != null && cls.id.isNotEmpty) ? cls.id : null,
                    filePath: attachedFilePath,
                  );
                  if (!hostContext.mounted) return;
                  if (ok) {
                    final updated = AssignmentEntity(
                      id: editing.id,
                      classId: editing.classId,
                      title: title.trim(),
                      description: description.trim(),
                      dueDate: dueDate.trim(),
                      points: pts,
                      status: editing.status,
                      grade: editing.grade,
                      feedback: editing.feedback,
                    );
                    onUpsertAssignment?.call(updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                        const SnackBar(content: Text('Assignment updated.')));
                  } else {
                    messenger.showSnackBar(const SnackBar(
                        content: Text(
                            'Could not update assignment. Check fields and network.')));
                  }
                } finally {
                  submitting[0] = false;
                  if (ctx.mounted) setDialogState(() {});
                }
                return;
              }
              onUpsertAssignment?.call(AssignmentEntity(
                id: editing.id,
                classId: editing.classId,
                title: title,
                description: description,
                dueDate: dueDate,
                points: pts,
                status: editing.status,
                grade: editing.grade,
                feedback: editing.feedback,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              return;
            }

            if (cls == null) return;

            if (title.trim().isEmpty || dueDate.trim().isEmpty) {
              messenger.showSnackBar(const SnackBar(
                  content: Text('Title and due date are required.')));
              return;
            }

            final remote = hostContext.read<AssignmentsRemoteDatasource>();
            final gid = cls.gradeId?.trim() ?? '';
            final sid = cls.subjectId?.trim() ?? '';

            if (remote.isConfigured && (gid.isEmpty || sid.isEmpty)) {
              messenger.showSnackBar(const SnackBar(
                content: Text(
                    'This class has no gradeId or subjectId from the server. Reload class details, then try again.'),
              ));
              return;
            }

            final useApi =
                remote.isConfigured && gid.isNotEmpty && sid.isNotEmpty;

            submitting[0] = true;
            setDialogState(() {});

            try {
              if (useApi) {
                final timeStr =
                    dueTime.trim().isEmpty ? '23:59' : dueTime.trim();
                final ok = await remote.createAssignment(
                  title: title.trim(),
                  description: description.trim(),
                  dueDate: dueDate.trim(),
                  dueTime: timeStr,
                  points: '$pts',
                  gradeId: gid,
                  subjectId: sid,
                  classId: cls.id,
                  filePath: attachedFilePath,
                );
                if (!hostContext.mounted) return;
                if (ok) {
                  onResetAssignmentsFromServer?.call();
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                      const SnackBar(content: Text('Assignment created.')));
                } else {
                  messenger.showSnackBar(const SnackBar(
                      content: Text(
                          'Could not create assignment. Check fields and network.')));
                }
                return;
              }

              final newAssign = AssignmentEntity(
                id: 'assign-${DateTime.now().millisecondsSinceEpoch}',
                classId: cls.id,
                title: title,
                description: description,
                dueDate: dueDate,
                points: pts,
                status: AssignmentStatus.pending,
              );
              if (onAppendAssignmentLocal != null) {
                onAppendAssignmentLocal(newAssign);
              } else {
                hostContext
                    .read<AssignmentsRepository>()
                    .addAssignment(newAssign);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            } finally {
              submitting[0] = false;
              if (ctx.mounted) setDialogState(() {});
            }
          }

          final mq = MediaQuery.of(ctx);
          final maxDialogHeight =
              (mq.size.height - mq.viewInsets.bottom - mq.padding.vertical - 48)
                  .clamp(220.0, mq.size.height);

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: dialogWidth, maxHeight: maxDialogHeight),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              editing != null
                                  ? _tr(
                                      lang,
                                      'teacherClassDetails.editAssignment',
                                      'Edit Assignment')
                                  : _tr(
                                      lang,
                                      'teacherClassDetails.createAssignment',
                                      'Create New Assignment'),
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
                      dialogLabel(
                          _tr(lang, 'teacherClassDetails.assignmentTitle',
                              'Assignment Title'),
                          required: true),
                      TextField(
                          decoration: inputDecoration('e.g., Math Homework'),
                          onChanged: (v) => title = v,
                          controller: TextEditingController(text: title)),
                      const SizedBox(height: 12),
                      dialogLabel(
                          _tr(lang, 'lessons.description', 'Description')),
                      TextField(
                          decoration: inputDecoration(
                              'Describe the assignment content...'),
                          maxLines: 3,
                          onChanged: (v) => description = v,
                          controller: TextEditingController(text: description)),
                      const SizedBox(height: 12),
                      dialogLabel(_tr(lang, 'assignments.dueDate', 'Due Date'),
                          required: true),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: teacherParseYmd(dueDate),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dueDate = teacherFormatYmd(picked);
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: inputDecoration(
                            _tr(lang, 'teacherClassDetails.tapToPickDate',
                                'Tap to choose date'),
                            prefixIcon: Icon(Icons.calendar_today,
                                size: 20, color: Colors.grey.shade600),
                          ),
                          child: Text(
                            dueDate,
                            style: const TextStyle(
                                fontSize: 14, color: labelColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      dialogLabel(
                          _tr(lang, 'teacherClassDetails.dueTime', 'Due Time')),
                      InkWell(
                        onTap: () async {
                          final initial = teacherParseHmOr(
                            const TimeOfDay(hour: 23, minute: 59),
                            dueTime,
                          );
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: initial,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dueTime = teacherFormatHm24(picked);
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: inputDecoration(
                            _tr(
                              lang,
                              'teacherClassDetails.tapToPickTime',
                              'Tap to choose time (optional)',
                            ),
                            suffixIcon: Icon(Icons.schedule,
                                size: 20, color: Colors.grey.shade600),
                          ),
                          child: Text(
                            dueTime.isEmpty
                                ? _tr(
                                    lang,
                                    'teacherClassDetails.dueTimeDefault',
                                    'Default: 23:59 if unset',
                                  )
                                : dueTime,
                            style: TextStyle(
                              fontSize: 14,
                              color: dueTime.isEmpty
                                  ? Colors.grey.shade600
                                  : labelColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      dialogLabel(_tr(lang, 'assignments.points', 'Points'),
                          required: true),
                      TextField(
                          decoration: inputDecoration('e.g., 100'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => points = v,
                          controller: TextEditingController(text: points)),
                      const SizedBox(height: 12),
                      if (apiCreateMissingIds) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            'Load this class from the server (gradeId & subjectId) to create assignments via API.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange.shade900),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (cls != null && useApiCreate) ...[
                        dialogLabel(_tr(lang,
                            'teacherClassDetails.classFromServer', 'Class')),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF3F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            '${cls.subject} · ${cls.level} — IDs sent with the request.',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: labelColor),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      dialogLabel(_tr(lang, 'teacherClassDetails.attachFiles',
                          'Attach Files')),
                      DottedBorder(
                        borderType: BorderType.RRect,
                        radius: const Radius.circular(8),
                        dashPattern: const [6, 4],
                        color: borderColor,
                        strokeWidth: 2,
                        child: InkWell(
                          onTap: () async {
                            final r = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['pdf'],
                            );
                            if (r != null && r.files.isNotEmpty) {
                              final f = r.files.single;
                              final path = f.path;
                              if (path != null && path.isNotEmpty) {
                                setDialogState(() {
                                  attachedFilePath = path;
                                  attachedFileName = f.name;
                                });
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(Icons.upload_file,
                                    size: 36, color: labelColor),
                                const SizedBox(height: 8),
                                Text(
                                  attachedFileName ??
                                      _tr(
                                        lang,
                                        'teacherClassDetails.attachPdfOnly',
                                        'Click to upload PDF',
                                      ),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: (attachedFileName ?? '').isEmpty
                                          ? Colors.grey.shade600
                                          : labelColor),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: labelColor,
                                backgroundColor: Colors.grey.shade100,
                                side: BorderSide(color: borderColor),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10)),
                            child: Text(_tr(lang, 'common.cancel', 'Cancel'),
                                style: const TextStyle(fontSize: 13)),
                          ),
                          FilledButton(
                            onPressed: (submitting[0] ||
                                    (editing == null && apiCreateMissingIds))
                                ? null
                                : submit,
                            style: FilledButton.styleFrom(
                                backgroundColor: labelColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10)),
                            child: submitting[0]
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(
                                    editing != null
                                        ? _tr(lang, 'common.update', 'Update')
                                        : _tr(
                                            lang,
                                            'teacherClassDetails.createAssignment',
                                            'Create Assignment'),
                                    style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
