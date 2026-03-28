import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/teacher_roster_student_entity.dart';
import 'package:high_school/domain/repositories/teacher_students_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class TeacherStudentsListScreen extends StatefulWidget {
  const TeacherStudentsListScreen({super.key});

  @override
  State<TeacherStudentsListScreen> createState() => _TeacherStudentsListScreenState();
}

class _TeacherStudentsListScreenState extends State<TeacherStudentsListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final repo = context.read<TeacherStudentsRepository>();

    return FutureBuilder<TeacherStudentsListResult>(
      key: ValueKey(_searchQuery),
      future: repo.listStudents(_searchQuery),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Material(color: Colors.transparent, child: Center(child: CircularProgressIndicator()));
        }
        final result = snapshot.data!;

        return Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(lang),
                const SizedBox(height: 16),
                _buildSearch(lang),
                const SizedBox(height: 16),
                _buildStats(context, lang, result),
                const SizedBox(height: 16),
                _buildStudentsList(context, lang, result.students),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildResultsCount(context, lang, result.students.length, result.total),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(LanguageProvider lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('students.studentsTitle'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
          ),
          const SizedBox(height: 4),
          Text(
            lang.t('students.viewEnrolledSubtitle'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, decoration: TextDecoration.none),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(LanguageProvider lang) {
    return TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: lang.t('students.searchPlaceholder'),
        prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildStats(BuildContext context, LanguageProvider lang, TeacherStudentsListResult result) {
    final avgGrade = result.students.isEmpty ? 0 : result.averageGradePercent.round().clamp(0, 100);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.people_outline,
            value: '${result.total}',
            label: lang.t('students.totalStudents'),
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book,
            value: '${result.distinctClassCount}',
            label: lang.t('students.classes'),
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up,
            value: '$avgGrade%',
            label: lang.t('students.avgGrade'),
            color: Colors.amber.shade700,
          ),
        ),
      ],
    );
  }

  List<String> _chipLabels(TeacherRosterStudentEntity student) {
    if (student.classes.isNotEmpty) {
      return student.classes.map((c) => c.displayLabel).toList();
    }
    return student.subjects;
  }

  Widget _buildStudentsList(BuildContext context, LanguageProvider lang, List<TeacherRosterStudentEntity> students) {
    if (students.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty ? lang.t('students.noStudentsFound') : lang.t('students.noStudentsEnrolled'),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: students.map((student) {
        final chips = _chipLabels(student);
        final contact = student.primaryContact;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0E8F7),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      student.name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').join('').toUpperCase(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F3C88), decoration: TextDecoration.none),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                student.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, decoration: TextDecoration.none),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDFF0D8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${student.avgGradePercent}%',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent, decoration: TextDecoration.none),
                              ),
                            ),
                          ],
                        ),
                        if (contact.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                student.hasEmail ? Icons.email_outlined : Icons.phone_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  contact,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, decoration: TextDecoration.none),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (student.gradeLevel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            student.gradeLevel,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          ),
                        ],
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: chips
                                .map(
                                  (label) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF3F9),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF4A5568), decoration: TextDecoration.none),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => context.go('/teacher/students/${student.id}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.trending_up, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lang.t('students.viewProgressAttendance'),
                                    style: const TextStyle(decoration: TextDecoration.none),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultsCount(BuildContext context, LanguageProvider lang, int filtered, int total) {
    final text = lang.t('students.showingStudents').replaceAll('{filtered}', '$filtered').replaceAll('{total}', '$total');
    return Center(
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary, decoration: TextDecoration.none)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, decoration: TextDecoration.none), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
