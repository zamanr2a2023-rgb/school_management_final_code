import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/teacher_profile_me_entity.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/domain/repositories/teacher_profile_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/widgets/language_selector_widget.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  Future<TeacherProfileMe?>? _profileFuture;

  String? _overrideName;
  String? _overridePhone;
  String? _overrideAddress;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].length >= 2
          ? parts[0].substring(0, 2).toUpperCase()
          : parts[0].toUpperCase();
    }
    return '${parts[0].isNotEmpty ? parts[0][0] : ''}${parts[1].isNotEmpty ? parts[1][0] : ''}'
        .toUpperCase();
  }

  static String _t(LanguageProvider lang, String key, String fallback) {
    final s = lang.t(key);
    return (s == key || s.isEmpty) ? fallback : s;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileFuture ??=
        context.read<TeacherProfileRepository>().getMyProfile();
  }

  String _name(UserEntity user, TeacherProfileMe? profile) =>
      _overrideName ?? profile?.name ?? user.name;

  String _phone(TeacherProfileMe? profile) =>
      _overridePhone ?? profile?.phone ?? '';

  String _address(TeacherProfileMe? profile) =>
      _overrideAddress ?? profile?.address ?? '';

  String _roleBadge(TeacherProfileMe? profile, UserEntity user, LanguageProvider lang) {
    if (user.subject != null && user.subject!.trim().isNotEmpty) {
      return '${user.subject!.trim()} ${lang.t('profile.teacherRole')}';
    }
    if (profile != null && profile.assignedClasses.isNotEmpty) {
      final s = profile.assignedClasses.first.subject.trim();
      if (s.isNotEmpty) return '$s ${lang.t('profile.teacherRole')}';
    }
    return lang.t('profile.teacherRole');
  }

  Future<void> _saveTeacherProfileEdit({
    required BuildContext rootContext,
    required TextEditingController nameCtrl,
    required TextEditingController addressCtrl,
    required String phoneLocked,
    required LanguageProvider lang,
  }) async {
    final name = nameCtrl.text.trim();
    final phone = phoneLocked.trim();
    final address = addressCtrl.text.trim();
    if (name.isEmpty) {
      if (rootContext.mounted) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          SnackBar(content: Text(lang.t('common.nameRequired'))),
        );
      }
      return;
    }

    final repo = rootContext.read<TeacherProfileRepository>();
    final auth = rootContext.read<AuthProvider>();
    final result = await repo.updateMyProfile(
      name: name,
      phone: phone,
      address: address,
    );

    if (!rootContext.mounted) return;
    final messenger = ScaffoldMessenger.of(rootContext);

    if (result == null) {
      setState(() {
        _overrideName = name;
        _overridePhone = phone;
        _overrideAddress = address;
      });
      messenger.showSnackBar(SnackBar(content: Text(lang.t('common.profileUpdated'))));
      return;
    }
    if (result) {
      final refreshed = await auth.refreshUserFromServer();
      if (!refreshed) {
        await auth.syncUserFromProfile(name: name, phone: phone);
      }
      setState(() {
        _overrideName = null;
        _overridePhone = null;
        _overrideAddress = null;
        _profileFuture = repo.getMyProfile();
      });
      messenger.showSnackBar(SnackBar(content: Text(lang.t('common.profileUpdated'))));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(lang.t('common.profileUpdateFailed'))));
    }
  }

  void _showEditDialog(
    BuildContext context,
    UserEntity user,
    TeacherProfileMe? profile,
    LanguageProvider lang,
  ) {
    final nameCtrl = TextEditingController(text: _name(user, profile));
    final addressCtrl = TextEditingController(text: _address(profile));
    final phoneLocked = _phone(profile);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.t('profile.editProfile')),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  lang.t('profile.personalInfo'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                _dialogField(context, lang.t('profile.fullName'), nameCtrl),
                _readOnlyPhoneBlock(context, lang, phoneLocked),
                _dialogField(
                  context,
                  lang.t('profile.address'),
                  addressCtrl,
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(lang.t('common.nameRequired'))),
                );
                return;
              }
              Navigator.pop(ctx);
              await _saveTeacherProfileEdit(
                rootContext: context,
                nameCtrl: nameCtrl,
                addressCtrl: addressCtrl,
                phoneLocked: phoneLocked,
                lang: lang,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text(lang.t('common.saveChanges')),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyPhoneBlock(
    BuildContext context,
    LanguageProvider lang,
    String phone,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('profile.phone'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              phone.isEmpty ? '—' : phone,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                    color: Colors.grey.shade800,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _inputDecoration(BuildContext context) {
    return InputDecoration(
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }

  Widget _dialogField(
    BuildContext context,
    String label,
    TextEditingController c, {
    TextInputType keyboardType = TextInputType.text,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: keyboardType,
            minLines: minLines,
            maxLines: maxLines,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.35),
            decoration: _inputDecoration(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox();

    final borderColor = AppTheme.primary.withValues(alpha: 0.2);

    return FutureBuilder<TeacherProfileMe?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data;

        return RefreshIndicator(
          onRefresh: () async {
            final f = context.read<TeacherProfileRepository>().getMyProfile();
            setState(() => _profileFuture = f);
            await f;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderBanner(lang: lang),
                if (profile == null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _t(
                        lang,
                        'profile.loadError',
                        'Could not load profile. Pull to refresh.',
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _BorderedCard(
                  borderColor: borderColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              width: 4,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: AppTheme.primary,
                            child: profile?.profileImageUrl != null &&
                                    profile!.profileImageUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      profile.profileImageUrl!,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Text(
                                        _initials(_name(user, profile)),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    _initials(_name(user, profile)),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _name(user, profile),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            _roleBadge(profile, user, lang),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 36,
                          child: FilledButton.icon(
                            onPressed: () => _showEditDialog(
                              context,
                              user,
                              profile,
                              lang,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text(
                              lang.t('profile.editProfile'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const Divider(height: 28),
                        _ContactRow(
                          icon: Icons.phone_outlined,
                          text: _phone(profile).isEmpty ? '—' : _phone(profile),
                        ),
                        _ContactRow(
                          icon: Icons.location_on_outlined,
                          text: _address(profile).isEmpty ? '—' : _address(profile),
                        ),
                      ],
                    ),
                  ),
                ),
                if (profile != null) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    borderColor: borderColor,
                    title: lang.t('profile.teachingOverviewTeacher'),
                    titleIcon: Icons.military_tech_outlined,
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _TeachingStatCell(
                          icon: Icons.menu_book_outlined,
                          label: lang.t('profile.classesLabel'),
                          value: '${profile.teachingOverview.totalClasses}',
                          tint: AppTheme.primary,
                        ),
                        _TeachingStatCell(
                          icon: Icons.people_outline,
                          label: lang.t('profile.studentsLabel'),
                          value: '${profile.teachingOverview.totalStudents}',
                          tint: AppTheme.secondary,
                        ),
                        _TeachingStatCell(
                          icon: Icons.description_outlined,
                          label: lang.t('profile.assignments'),
                          value: '${profile.teachingOverview.totalAssignments}',
                          tint: AppTheme.accent,
                        ),
                        _TeachingStatCell(
                          icon: Icons.fact_check_outlined,
                          label: lang.t('profile.gradedSubmissions'),
                          value:
                              '${profile.teachingOverview.totalGradedSubmissions}',
                          tint: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    borderColor: borderColor,
                    title: lang.t('profile.teachingClasses'),
                    titleIcon: Icons.menu_book_outlined,
                    child: profile.assignedClasses.isEmpty
                        ? Text(
                            lang.t('profile.noClassesAssigned'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          )
                        : Column(
                            children: profile.assignedClasses
                                .map(
                                  (c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppTheme.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.className,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (c.gradeLevel.isNotEmpty ||
                                                    c.subject.isNotEmpty)
                                                  Text(
                                                    [
                                                      if (c.gradeLevel
                                                          .isNotEmpty)
                                                        c.gradeLevel,
                                                      if (c.subject.isNotEmpty)
                                                        c.subject,
                                                    ].join(' · '),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: borderColor,
                                              ),
                                            ),
                                            child: Text(
                                              '${c.totalStudents} ${lang.t('profile.studentsLabel').toLowerCase()}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
                const SizedBox(height: 16),
                _BorderedCard(
                  borderColor: borderColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.t('profile.languagePreference'),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const LanguageSelectorWidget(),
                      ],
                    ),
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

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.lang});

  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('profile.myProfile'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lang.t('profile.manageProfessionalInfo'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.normal,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _BorderedCard extends StatelessWidget {
  const _BorderedCard({
    required this.borderColor,
    required this.child,
  });

  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.borderColor,
    required this.title,
    required this.titleIcon,
    required this.child,
  });

  final Color borderColor;
  final String title;
  final IconData titleIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _BorderedCard(
      borderColor: borderColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(titleIcon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeachingStatCell extends StatelessWidget {
  const _TeachingStatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
          ),
        ],
      ),
    );
  }
}
