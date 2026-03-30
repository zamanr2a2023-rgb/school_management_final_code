import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/screens/teacher/teacher_dialog_date_time.dart';

String _tr(LanguageProvider lang, String key, String fallback) {
  final s = lang.t(key);
  return (s == key || s.isEmpty) ? fallback : s;
}

/// Same flow as [showTeacherCreateLessonDialog]: caller picks a class first, then opens this form.
/// Sends `gradeId`, `subjectId`, `classId` from [cls] with POST /api/v1/sessions when API is configured.
void showTeacherCreateLiveSessionDialog(
  BuildContext hostContext,
  LanguageProvider lang,
  ClassEntity cls, {
  VoidCallback? onSuccess,
}) {
  showDialog<void>(
    context: hostContext,
    useRootNavigator: true,
    builder: (ctx) => _TeacherCreateLiveSessionDialog(
      hostContext: hostContext,
      lang: lang,
      cls: cls,
      onSuccess: onSuccess,
    ),
  );
}

class _TeacherCreateLiveSessionDialog extends StatefulWidget {
  const _TeacherCreateLiveSessionDialog({
    required this.hostContext,
    required this.lang,
    required this.cls,
    this.onSuccess,
  });

  final BuildContext hostContext;
  final LanguageProvider lang;
  final ClassEntity cls;
  final VoidCallback? onSuccess;

  @override
  State<_TeacherCreateLiveSessionDialog> createState() =>
      _TeacherCreateLiveSessionDialogState();
}

class _TeacherCreateLiveSessionDialogState extends State<_TeacherCreateLiveSessionDialog> {
  /// Must match [showTeacherCreateLiveSessionDialog] which uses [useRootNavigator: true].
  void _popCreateRoute() {
    FocusManager.instance.primaryFocus?.unfocus();
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop();
      return;
    }
    final nested = Navigator.maybeOf(context);
    if (nested != null && nested.canPop()) nested.pop();
  }

  late final TextEditingController _titleCtrl;
  late final TextEditingController _classNameCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _zoomCtrl;

  bool _submitting = false;
  /// Inline validation under the Zoom link field (visible on submit / blur).
  String? _zoomLinkError;

  static const _labelColor = Color(0xFF1F3C88);
  static const _borderColor = Color(0xFFD1D5DB);

  @override
  void initState() {
    super.initState();
    final c = widget.cls;
    final defaultName =
        c.name.trim().isNotEmpty ? c.name.trim() : '${c.subject} · ${c.level}';
    _titleCtrl = TextEditingController();
    _classNameCtrl = TextEditingController(text: defaultName);
    _dateCtrl = TextEditingController(
      text: teacherFormatYmd(DateTime.now()),
    );
    _timeCtrl = TextEditingController(
      text: teacherFormatHm24(const TimeOfDay(hour: 10, minute: 0)),
    );
    _durationCtrl = TextEditingController(text: '60');
    _zoomCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _classNameCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _durationCtrl.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint, {Widget? suffix, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 4,
      isDense: true,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      errorStyle: const TextStyle(fontSize: 12, height: 1.25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, maxHeight: 40),
    );
  }

  /// Requires non-empty `http`/`https` URL with a host (e.g. Zoom / Meet link).
  bool _isValidMeetingLink(String raw) {
    final zoom = raw.trim();
    if (zoom.isEmpty) return false;
    final uri = Uri.tryParse(zoom);
    if (uri == null || !uri.hasScheme) return false;
    final s = uri.scheme.toLowerCase();
    if (s != 'http' && s != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  Widget _requiredLabel(String text) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _labelColor,
        ),
        children: [
          TextSpan(text: '$text '),
          const TextSpan(
            text: '*',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSessionDate() async {
    if (_submitting) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: teacherParseYmd(_dateCtrl.text),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _dateCtrl.text = teacherFormatYmd(picked));
    }
  }

  Future<void> _pickSessionTime() async {
    if (_submitting) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: teacherParseHmOr(
        const TimeOfDay(hour: 10, minute: 0),
        _timeCtrl.text,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _timeCtrl.text = teacherFormatHm24(picked));
    }
  }

  void _showSnack(String text) {
    final mq = MediaQuery.of(context);
    final bottom = mq.padding.bottom + mq.viewInsets.bottom;
    final snack = SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
    );
    final m = ScaffoldMessenger.maybeOf(widget.hostContext) ??
        ScaffoldMessenger.maybeOf(context);
    m?.showSnackBar(snack);
  }

  Future<void> _submit() async {
    final lang = widget.lang;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showSnack(
        '${_tr(lang, 'live.sessionTitle', 'Session Title')} ${_tr(lang, 'live.fieldRequired', 'is required')}',
      );
      return;
    }
    final date = _dateCtrl.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      _showSnack(
        _tr(lang, 'live.dateFormatHint', 'Use date format YYYY-MM-DD'),
      );
      return;
    }
    final time = _timeCtrl.text.trim();
    if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(time)) {
      _showSnack(
        _tr(lang, 'live.timeFormatHint', 'Use time format HH:mm (24-hour)'),
      );
      return;
    }
    final dur = int.tryParse(_durationCtrl.text.trim());
    if (dur == null || dur <= 0) {
      _showSnack(
        _tr(
          lang,
          'live.durationInvalid',
          'Enter a valid duration in minutes',
        ),
      );
      return;
    }
    final zoom = _zoomCtrl.text.trim();
    if (zoom.isEmpty) {
      setState(() {
        _zoomLinkError = _tr(
          lang,
          'live.zoomLinkRequired',
          'Meeting link is required.',
        );
      });
      return;
    }
    if (!_isValidMeetingLink(zoom)) {
      setState(() {
        _zoomLinkError = _tr(
          lang,
          'live.zoomUrlInvalid',
          'Enter a valid link starting with https:// (e.g. https://zoom.us/j/...)',
        );
      });
      return;
    }
    setState(() => _zoomLinkError = null);

    final repo = context.read<LiveSessionsRepository>();
    final cls = widget.cls;
    final gid = cls.gradeId?.trim() ?? '';
    final sid = cls.subjectId?.trim() ?? '';
    final cid = cls.id.trim();

    if (repo.teacherSessionsApiConfigured) {
      if (gid.isEmpty || sid.isEmpty || cid.isEmpty) {
        _showSnack(
          _tr(
            lang,
            'live.missingClassIds',
            'This class has no gradeId, subjectId, or id from the server. Open the class while online, then try again.',
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final result = await repo.createTeacherLiveSession(
        title: title,
        gradeId: gid,
        subjectId: sid,
        classId: cid,
        className: _classNameCtrl.text.trim(),
        date: date,
        time: time,
        duration: dur,
        zoomLink: zoom,
      );
      if (!mounted) return;
      if (result.success) {
        // Always show this approval copy in the popup (matches product copy / API intent).
        final msg = _tr(
          lang,
          'live.sessionCreatedPendingApproval',
          'Session created and sent for admin approval',
        );
        final onRefresh = widget.onSuccess;
        if (!mounted) return;
        setState(() => _submitting = false);
        // Stack success on top of the create dialog (same root navigator). Showing after pop was unreliable.
        showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (successCtx) => AlertDialog(
            icon: Icon(Icons.check_circle, color: Colors.green.shade600, size: 40),
            title: Text(
              _tr(lang, 'live.sessionCreatedTitle', 'Success'),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(successCtx, rootNavigator: true).pop();
                  if (!mounted) return;
                  _popCreateRoute();
                  onRefresh?.call();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(_tr(lang, 'common.confirm', 'OK')),
              ),
            ],
          ),
        );
      } else {
        setState(() => _submitting = false);
        _showSnack(
          result.message ??
              _tr(
                lang,
                'live.createSessionFailed',
                'Could not create session. Try again.',
              ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
      _showSnack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final cls = widget.cls;
    final repo = context.read<LiveSessionsRepository>();
    final apiOn = repo.teacherSessionsApiConfigured;
    final gid = cls.gradeId?.trim() ?? '';
    final sid = cls.subjectId?.trim() ?? '';
    final showIdWarning = apiOn && (gid.isEmpty || sid.isEmpty || cls.id.trim().isEmpty);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = (screenWidth > 420) ? 400.0 : (screenWidth - 24);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _tr(lang, 'live.createLiveSession', 'Create Live Session'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : _popCreateRoute,
                    icon: const Icon(Icons.close, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _requiredLabel(
                _tr(lang, 'teacherClassDetails.classFromServer', 'Class'),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cls.subject} · ${cls.level}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _labelColor,
                        fontSize: 14,
                      ),
                    ),
                    if (cls.name.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        cls.name.trim(),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _tr(
                        lang,
                        'live.classIdsUsed',
                        'gradeId, subjectId, and classId are taken from this class for the request.',
                      ),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              if (showIdWarning) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    _tr(
                      lang,
                      'live.missingClassIds',
                      'This class has no gradeId or subjectId from the server. Reload class details while online, then try again.',
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _requiredLabel(_tr(lang, 'live.sessionTitle', 'Session Title')),
              const SizedBox(height: 4),
              TextField(
                controller: _titleCtrl,
                decoration: _decoration(
                  _tr(
                    lang,
                    'live.sessionTitlePlaceholder',
                    'e.g., Mathematics Q&A Session',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _requiredLabel(_tr(lang, 'live.className', 'Class Name')),
              const SizedBox(height: 4),
              TextField(
                controller: _classNameCtrl,
                decoration: _decoration(
                  _tr(
                    lang,
                    'live.classPlaceholder',
                    'e.g., Grade 10 - Mathematics A',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _requiredLabel(_tr(lang, 'live.date', 'Date')),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _pickSessionDate,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: _decoration(
                              _tr(
                                lang,
                                'teacherClassDetails.tapToPickDate',
                                'Tap to choose date',
                              ),
                              suffix: Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            child: Text(
                              _dateCtrl.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _labelColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _requiredLabel(_tr(lang, 'live.time', 'Time')),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _pickSessionTime,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: _decoration(
                              _tr(
                                lang,
                                'live.tapToPickTime',
                                'Tap to choose time',
                              ),
                              suffix: Icon(
                                Icons.schedule,
                                size: 20,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            child: Text(
                              _timeCtrl.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _labelColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _requiredLabel(_tr(lang, 'lessons.duration', 'Duration')),
              const SizedBox(height: 4),
              TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                decoration: _decoration('60'),
              ),
              const SizedBox(height: 12),
              _requiredLabel(
                _tr(lang, 'live.zoomMeetingLink', 'Zoom Meeting Link'),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _zoomCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (_) {
                  if (_zoomLinkError != null) {
                    setState(() => _zoomLinkError = null);
                  }
                },
                onEditingComplete: () {
                  final t = _zoomCtrl.text.trim();
                  if (t.isEmpty) return;
                  if (!_isValidMeetingLink(t)) {
                    setState(() {
                      _zoomLinkError = _tr(
                        widget.lang,
                        'live.zoomUrlInvalid',
                        'Enter a valid link starting with https:// (e.g. https://zoom.us/j/...)',
                      );
                    });
                  }
                },
                decoration: _decoration(
                  'https://zoom.us/j/...',
                  errorText: _zoomLinkError,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _popCreateRoute,
                      child: Text(
                        _tr(lang, 'common.cancel', 'Cancel'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _tr(
                                lang,
                                'live.createSession',
                                'Create Session',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
