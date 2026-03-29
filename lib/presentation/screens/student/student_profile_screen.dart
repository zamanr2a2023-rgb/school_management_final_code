import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/student_profile_me_entity.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/domain/repositories/student_profile_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/widgets/language_selector_widget.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  /// Local overrides after Edit Profile (until next fetch). Null = use API value.
  String? _overrideName;
  String? _overridePhone;
  String? _overrideAddress;

  Future<StudentProfileMe?>? _profileFuture;

  static String _initials(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join()
        .toUpperCase();
  }

  static String _t(LanguageProvider lang, String key, String fallback) {
    final s = lang.t(key);
    return (s == key || s.isEmpty) ? fallback : s;
  }

  static String _formatPercentStat(num value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}%';
    }
    return '${value.toStringAsFixed(1)}%';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileFuture ??=
        context.read<StudentProfileRepository>().getMyProfile();
  }

  String _name(UserEntity user, StudentProfileMe? profile) =>
      _overrideName ?? profile?.name ?? user.name;

  String _phone(StudentProfileMe? profile) =>
      _overridePhone ?? profile?.phone ?? '';

  String _address(StudentProfileMe? profile) =>
      _overrideAddress ?? profile?.address ?? '';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox();

    return FutureBuilder<StudentProfileMe?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data;

        return RefreshIndicator(
          onRefresh: () async {
            final future =
                context.read<StudentProfileRepository>().getMyProfile();
            setState(() => _profileFuture = future);
            await future;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(lang),
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
                _buildProfileCard(context, user, profile, lang),
                const SizedBox(height: 16),
                _buildAcademicCard(context, lang, profile),
                const SizedBox(height: 16),
                _buildCurrentClassesCard(context, lang, profile),
                const SizedBox(height: 16),
                _buildLanguageCard(context, lang),
                const SizedBox(height: 24),
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
            _t(lang, 'profile.managePersonalInfo',
                'Manage your personal information'),
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

  Widget _buildProfileCard(
    BuildContext context,
    UserEntity user,
    StudentProfileMe? profile,
    LanguageProvider lang,
  ) {
    final displayName = _name(user, profile);
    final phone = _phone(profile);
    final address = _address(profile);
    final imageUrl = profile?.profileImageUrl;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          _initials(displayName),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      _initials(displayName),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (profile != null && profile.role.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  profile.role,
                  style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                ),
              ),
            ],
            if (user.grade != null && user.grade!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  user.grade!,
                  style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showEditDialog(context, user, profile, lang),
              icon: const Icon(Icons.edit, size: 18),
              label: Text(_t(lang, 'profile.editProfile', 'Edit Profile')),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone, size: 18, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    phone.isEmpty ? '—' : phone,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 18, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    address.isEmpty ? '—' : address,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveStudentProfileEdit({
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

    final repo = rootContext.read<StudentProfileRepository>();
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
    StudentProfileMe? profile,
    LanguageProvider lang,
  ) {
    final nameCtrl = TextEditingController(text: _name(user, profile));
    final addressCtrl = TextEditingController(text: _address(profile));
    final phoneLocked = _phone(profile);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t(lang, 'profile.editProfile', 'Edit Profile')),
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
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                _editField(context, lang.t('profile.fullName'), nameCtrl),
                _readOnlyPhoneBlock(context, lang, phoneLocked),
                _editField(
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
              await _saveStudentProfileEdit(
                rootContext: context,
                nameCtrl: nameCtrl,
                addressCtrl: addressCtrl,
                phoneLocked: phoneLocked,
                lang: lang,
              );
            },
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
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.grey.shade700),
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

  Widget _editField(
    BuildContext context,
    String label,
    TextEditingController controller, {
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
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            minLines: minLines,
            maxLines: maxLines,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.35),
            decoration: InputDecoration(
              isDense: false,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicCard(
    BuildContext context,
    LanguageProvider lang,
    StudentProfileMe? profile,
  ) {
    final a = profile?.academic;
    final totalClasses = a?.totalClasses ?? 0;
    final assignments = a?.assignmentsDisplay ?? '—';
    final avg = a?.averageGrade ?? 0;
    final att = a?.attendance ?? 0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  lang.t('profile.academicOverview'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _StatBox(
                  icon: Icons.menu_book,
                  label: lang.t('profile.totalClasses'),
                  value: '$totalClasses',
                  color: AppTheme.primary,
                ),
                _StatBox(
                  icon: Icons.assignment,
                  label: lang.t('profile.assignments'),
                  value: assignments,
                  color: AppTheme.secondary,
                ),
                _StatBox(
                  icon: Icons.emoji_events,
                  label: lang.t('profile.averageGrade'),
                  value: _formatPercentStat(avg),
                  color: AppTheme.accent,
                ),
                _StatBox(
                  icon: Icons.calendar_today,
                  label: lang.t('profile.attendance'),
                  value: _formatPercentStat(att),
                  color: AppTheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentClassesCard(
    BuildContext context,
    LanguageProvider lang,
    StudentProfileMe? profile,
  ) {
    final list = profile?.currentClasses ?? [];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  lang.t('profile.currentClasses'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Text(
                _t(lang, 'profile.noCurrentClasses', 'No classes to show.'),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              )
            else
              ...list.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.subject,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            c.teacherName,
                            style: const TextStyle(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context, LanguageProvider lang) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.t('profile.languagePreference'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            const LanguageSelectorWidget(),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
