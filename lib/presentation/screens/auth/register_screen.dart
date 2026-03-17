import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/domain/entities/subject_entity.dart';
import 'package:high_school/domain/repositories/subjects_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/widgets/language_selector_widget.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RegisterBody();
  }
}

class _RegisterBody extends StatefulWidget {
  const _RegisterBody();

  @override
  State<_RegisterBody> createState() => _RegisterBodyState();
}

class _RegisterBodyState extends State<_RegisterBody> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String _role = 'student';
  String _grade = '';
  String _subject = '';
  String? _teacherSubjectId;
  final List<String> _selectedSubjects = [];
  final List<String> _selectedTeacherGrades = [];
  static const List<String> _teacherGradeOptions = ['4th', '5th', '6th', '7th'];
  Future<List<SubjectEntity>>? _subjectsFuture;
  String? _error;
  bool _success = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Widget _buildSubjectChips(BuildContext context, LanguageProvider lang) {
    _subjectsFuture ??= context.read<SubjectsRepository>().getSubjects();
    return FutureBuilder<List<SubjectEntity>>(
      future: _subjectsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final options = snapshot.data!;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((sub) {
            final name = sub.name;
            final selected = _selectedSubjects.contains(name);
            return FilterChip(
              label: Text(name),
              selected: selected,
              onSelected: (v) {
                setState(() {
                  if (v == true) {
                    _selectedSubjects.add(name);
                  } else {
                    _selectedSubjects.remove(name);
                  }
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTeacherSubjectDropdown(BuildContext context, LanguageProvider lang) {
    _subjectsFuture ??= context.read<SubjectsRepository>().getSubjects();
    return FutureBuilder<List<SubjectEntity>>(
      future: _subjectsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final subjects = snapshot.data!;
        return DropdownButtonFormField<String>(
          value: _teacherSubjectId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          hint: Text(lang.t('auth.subjectExample')),
          items: subjects
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s.id,
                  child: Text(s.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _teacherSubjectId = value;
              if (value == null) {
                _subject = '';
              } else {
                final selected = subjects.firstWhere(
                  (s) => s.id == value,
                  orElse: () => subjects.first,
                );
                _subject = selected.name;
              }
            });
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();

    if (_pinController.text != _confirmPinController.text) {
      setState(() {
        _error = 'PINs do not match';
        _loading = false;
      });
      return;
    }
    if (_pinController.text.length != 4) {
      setState(() {
        _error = 'PIN must be exactly 4 digits';
        _loading = false;
      });
      return;
    }
    if (_role == 'student' && _grade.isEmpty) {
      setState(() {
        _error = 'Please select your grade';
        _loading = false;
      });
      return;
    }
    if (_role == 'student' && _selectedSubjects.isEmpty) {
      setState(() {
        _error = 'Please select at least one subject';
        _loading = false;
      });
      return;
    }
    if (_role == 'teacher' && _teacherSubjectId == null) {
      setState(() {
        _error = 'Please enter your subject';
        _loading = false;
      });
      return;
    }
    if (_role == 'teacher' && _selectedTeacherGrades.isEmpty) {
      setState(() {
        _error = lang.t('auth.selectAtLeastOneGrade');
        _loading = false;
      });
      return;
    }

    final ok = await auth.register(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      pin: _pinController.text,
      role: _role,
      grade: _grade.isEmpty ? null : _grade,
      subject: _subject.isEmpty ? null : _subject,
      subjectId: _teacherSubjectId,
      assignedSubjects: _role == 'student' && _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
      assignedGrades: _role == 'teacher' && _selectedTeacherGrades.isNotEmpty ? _selectedTeacherGrades : null,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _success = ok;
    });
    if (ok && _role == 'student') {
      context.go('/otp/send', extra: _phoneController.text.trim());
    } else if (ok && _role == 'teacher') {
      // Teacher pending - stay on success message
    } else if (!ok) {
      setState(() => _error = auth.lastAuthError ?? 'Phone number already registered');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (_success && _role == 'teacher') {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(lang.t('auth.registrationSuccessful'), style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(lang.t('auth.teacherAccountPending'), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: Text(lang.t('auth.goToLogin')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(lang.t('auth.createAccount'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(lang.t('auth.registerSubtitle'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              const LanguageSelectorWidget(),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: lang.t('auth.fullName'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: lang.t('auth.enterPhoneNumber'), border: const OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Text(lang.t('auth.iAmA'), style: Theme.of(context).textTheme.labelMedium),
              Row(
                children: [
                  Radio<String>(
                    value: 'student',
                    groupValue: _role,
                    onChanged: (v) => setState(() {
                      _role = v!;
                      _selectedTeacherGrades.clear();
                      _teacherSubjectId = null;
                      _subject = '';
                    }),
                  ),
                  Text(lang.t('auth.student')),
                  Radio<String>(
                    value: 'teacher',
                    groupValue: _role,
                    onChanged: (v) => setState(() {
                      _role = v!;
                      _selectedSubjects.clear();
                      _grade = '';
                    }),
                  ),
                  Text(lang.t('auth.teacher')),
                ],
              ),
              if (_role == 'student') ...[
                Text(lang.t('classes.grade'), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _grade.isNotEmpty && ['4th', '5th', '6th', '7th'].contains(_grade) ? _grade : null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  hint: Text(lang.t('auth.gradeExample')),
                  items: const [
                    DropdownMenuItem(value: '4th', child: Text('4th')),
                    DropdownMenuItem(value: '5th', child: Text('5th')),
                    DropdownMenuItem(value: '6th', child: Text('6th')),
                    DropdownMenuItem(value: '7th', child: Text('7th')),
                  ],
                  onChanged: (v) => setState(() => _grade = v ?? ''),
                ),
                const SizedBox(height: 12),
                Text(lang.t('classes.subject'), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text('Select at least one subject', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 6),
                _buildSubjectChips(context, lang),
                const SizedBox(height: 12),
              ],
              if (_role == 'teacher') ...[
                Text(lang.t('classes.subject'), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                _buildTeacherSubjectDropdown(context, lang),
                const SizedBox(height: 12),
                Text(lang.t('classes.grade'), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(lang.t('auth.selectAtLeastOneGrade'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _teacherGradeOptions.map((g) {
                    final selected = _selectedTeacherGrades.contains(g);
                    return FilterChip(
                      label: Text(g),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedTeacherGrades.add(g);
                          } else {
                            _selectedTeacherGrades.remove(g);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _pinController,
                decoration: InputDecoration(labelText: lang.t('auth.enterPin'), border: const OutlineInputBorder()),
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _confirmPinController,
                decoration: InputDecoration(labelText: lang.t('auth.confirmPin'), border: const OutlineInputBorder()),
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Text(lang.t('auth.registerButton')),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(lang.t('auth.noAccount') + ' ' + lang.t('auth.login')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
