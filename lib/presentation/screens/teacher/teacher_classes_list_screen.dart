import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/repositories/teacher_classes_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class TeacherClassesListScreen extends StatefulWidget {
  const TeacherClassesListScreen({super.key});

  @override
  State<TeacherClassesListScreen> createState() =>
      _TeacherClassesListScreenState();
}

class _TeacherClassesListScreenState extends State<TeacherClassesListScreen> {
  String _gradeFilter = 'all';
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final teacherId = auth.user?.id == 'demo_teacher'
        ? 'teacher1'
        : (auth.user?.id ?? 'teacher1');

    return FutureBuilder<List<ClassEntity>>(
      future: context.read<TeacherClassesRepository>().getMyClasses(teacherId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final myClasses = snapshot.data!;
        final grades = myClasses.map((c) => c.level).toSet().toList()..sort();
        final filteredClasses = _gradeFilter == 'all'
            ? myClasses
            : myClasses.where((c) => c.level == _gradeFilter).toList();
        final hasActiveFilters = _gradeFilter != 'all';

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, lang, filteredClasses.length),
              const SizedBox(height: 16),
              if (_showFilters) ...[
                _buildFiltersPanel(context, lang, grades, hasActiveFilters),
                const SizedBox(height: 16),
              ],
              _buildResultsCount(context, lang, filteredClasses.length),
              const SizedBox(height: 12),
              filteredClasses.isEmpty
                  ? _buildEmptyState(context, lang, hasActiveFilters)
                  : _buildClassesList(context, lang, filteredClasses),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, LanguageProvider lang, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.t('classes.myClasses'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    height: 1.25,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  count == 1
                      ? '1 ${lang.t('classes.assignedToYou')}'
                      : '$count ${lang.t('classes.assignedToYouPlural')}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: const Icon(Icons.tune, color: Colors.white, size: 26),
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context, LanguageProvider lang,
      List<String> grades, bool hasActiveFilters) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasActiveFilters)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _gradeFilter = 'all'),
                  child: Text(lang.t('classes.resetAll'),
                      style: const TextStyle(
                          color: AppTheme.primary, fontSize: 12)),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.school, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(lang.t('classes.grade'),
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _gradeFilter,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.2))),
              ),
              items: [
                DropdownMenuItem(
                    value: 'all', child: Text(lang.t('classes.allGrades'))),
                ...grades
                    .map((g) => DropdownMenuItem(value: g, child: Text(g))),
              ],
              onChanged: (v) => setState(() => _gradeFilter = v ?? 'all'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCount(
      BuildContext context, LanguageProvider lang, int count) {
    final text = count == 0
        ? lang.t('classes.noClassesFound')
        : count == 1
            ? lang.t('classes.showingClass')
            : lang.t('classes.showingClasses').replaceAll('{count}', '$count');
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.35,
          color: Colors.blueGrey.shade400,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, LanguageProvider lang, bool hasActiveFilters) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.menu_book, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(lang.t('classes.noClassesMatchFilters'),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
            if (hasActiveFilters) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => _gradeFilter = 'all'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                child: Text(lang.t('classes.clearFilters')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const Color _gradePillBg = Color(0xFFE8F5E9);
  static const Color _gradePillBorder = Color(0xFF81C784);
  static const Color _gradePillText = Color(0xFF1B5E20);
  static const Color _cardMetaText = Color(0xFF5C6B8A);

  /// Format schedule for display. Converts API raw format e.g. [{day: sat, startMin: 540, endMin: 600}] to "Sat 9:00 AM - 10:00 AM".
  static String _formatSchedule(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final s = raw.trim();
    if (!s.startsWith('[') || (!s.contains('startMin') && !s.contains('startTime'))) return s;
    const dayNames = {'sun': 'Sun', 'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu', 'fri': 'Fri', 'sat': 'Sat'};
    try {
      final list = jsonDecode(s) as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        final parts = <String>[];
        for (final e in list) {
          final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
          final day = (map['day']?.toString() ?? '').toLowerCase();
          final startMin = map['startMin'] is int ? map['startMin'] as int : int.tryParse(map['startMin']?.toString() ?? '') ?? 0;
          final endMin = map['endMin'] is int ? map['endMin'] as int : int.tryParse(map['endMin']?.toString() ?? '') ?? 0;
          final startTime = _minToTimeStr(startMin);
          final endTime = _minToTimeStr(endMin);
          final dayLabel = dayNames[day] ?? day;
          parts.add('$dayLabel $startTime - $endTime');
        }
        return parts.join(', ');
      }
    } catch (_) {}
    final regex = RegExp(r'day:\s*(\w+)[\s\S]*?startMin:\s*(\d+)[\s\S]*?endMin:\s*(\d+)');
    final matches = regex.allMatches(s);
    if (matches.isNotEmpty) {
      final parts = matches.map((m) {
        final day = m.group(1)!.toLowerCase();
        final startMin = int.tryParse(m.group(2) ?? '') ?? 0;
        final endMin = int.tryParse(m.group(3) ?? '') ?? 0;
        final dayLabel = dayNames[day] ?? day;
        return '$dayLabel ${_minToTimeStr(startMin)} - ${_minToTimeStr(endMin)}';
      }).toList();
      return parts.join(', ');
    }
    return s;
  }

  static String _minToTimeStr(int minFromMidnight) {
    final h = minFromMidnight ~/ 60;
    final m = minFromMidnight % 60;
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hour:${m.toString().padLeft(2, '0')} $ampm';
  }

  Widget _buildClassesList(
      BuildContext context, LanguageProvider lang, List<ClassEntity> classes) {
    final cardBorder = AppTheme.primary.withValues(alpha: 0.22);
    return Column(
      children: classes
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/teacher/classes/${c.id}'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  c.subject,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                    height: 1.2,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _gradePillBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _gradePillBorder, width: 1),
                                ),
                                child: Text(
                                  c.level.endsWith('Grade') || c.level.endsWith('grade')
                                      ? c.level
                                      : '${c.level} Grade',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _gradePillText,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatSchedule(c.schedule),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                    color: _cardMetaText,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 20,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${c.students} ${lang.t('classes.studentsEnrolled')}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _cardMetaText,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
