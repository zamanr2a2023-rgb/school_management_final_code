import 'package:flutter/material.dart';

String teacherFormatYmd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String teacherFormatHm24(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

DateTime teacherParseYmd(String s) {
  if (s.length >= 10) {
    final d = DateTime.tryParse(s.substring(0, 10));
    if (d != null) return DateTime(d.year, d.month, d.day);
  }
  return DateTime.now();
}

TimeOfDay teacherParseHmOr(TimeOfDay fallback, String s) {
  final trimmed = s.trim();
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
  if (m != null) {
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h != null &&
        min != null &&
        h >= 0 &&
        h < 24 &&
        min >= 0 &&
        min < 60) {
      return TimeOfDay(hour: h, minute: min);
    }
  }
  return fallback;
}

/// Raw due string from assignment entity; returns `[dateYmd, timeHm24]`.
/// Empty time means create flow may send API default 23:59.
List<String> teacherAssignmentInitialDue(String? rawDue) {
  final today = teacherFormatYmd(DateTime.now());
  final raw = (rawDue ?? '').trim();
  if (raw.isEmpty) return [today, ''];
  try {
    final dt = DateTime.parse(raw);
    return [
      teacherFormatYmd(dt),
      teacherFormatHm24(TimeOfDay(hour: dt.hour, minute: dt.minute)),
    ];
  } catch (_) {
    if (raw.length >= 10 &&
        RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw.substring(0, 10))) {
      return [raw.substring(0, 10), ''];
    }
    return [raw, ''];
  }
}
