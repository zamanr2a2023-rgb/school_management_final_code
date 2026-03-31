import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/presentation/widgets/garini_logo.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class LayoutWidget extends StatelessWidget {
  const LayoutWidget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();

    if (!auth.isAuthenticated) {
      return SizedBox(height: double.infinity, child: child);
    }

    final user = auth.user!;
    final isStudent = user.role == UserRole.student;
    final navItems = isStudent
        ? [
            _NavItem(path: '/student/dashboard', label: lang.t('nav.home'), icon: Icons.home),
            _NavItem(path: '/student/classes', label: lang.t('nav.classes'), icon: Icons.menu_book),
            _NavItem(path: '/student/timetable', label: lang.t('timetable.timetable'), icon: Icons.calendar_today),
            _NavItem(path: '/student/live-sessions', label: lang.t('live.liveSessions'), icon: Icons.video_call),
          ]
        : [
            _NavItem(path: '/teacher/dashboard', label: lang.t('nav.home'), icon: Icons.home),
            _NavItem(path: '/teacher/classes', label: lang.t('nav.classes'), icon: Icons.menu_book),
            _NavItem(path: '/teacher/students', label: lang.t('nav.students'), icon: Icons.people),
            _NavItem(path: '/teacher/live-sessions', label: lang.t('live.liveSessions'), icon: Icons.video_call),
          ];

    final location = GoRouterState.of(context).uri.path;
    final canGoBack = !location.contains('dashboard');

    void onBackPressed() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      final segments = location.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.length > 2) {
        var parentPath = '/${segments.sublist(0, segments.length - 1).join('/')}';
        // No index route for /teacher/assignments (only /teacher/assignments/:id).
        if (parentPath == '/teacher/assignments') {
          parentPath = '/teacher/classes';
        }
        context.go(parentPath);
      }
    }

    return Column(
      children: [
        Material(
          color: Colors.white,
          elevation: 2,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (canGoBack)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
                      onPressed: onBackPressed,
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GariniLogo(
                          size: 32,
                          fit: BoxFit.cover,
                          fallbackColor: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppConstants.appName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                        ),
                      ],
                    ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: AppTheme.primary),
                        onPressed: () => context.go('/notifications'),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text('3', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Tooltip(
                      message: lang.t('profile.myProfile'),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.go(
                            isStudent ? '/student/profile' : '/teacher/profile',
                          ),
                          customBorder: const CircleBorder(),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              _initials(user.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppTheme.primary),
                    onPressed: () {
                      final roleLabel = user.role == UserRole.student
                          ? lang.t('auth.student')
                          : lang.t('auth.teacher');
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 12,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: AppTheme.primary,
                                        child: Text(
                                          _initials(user.name),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.name,
                                              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF1A1A1A),
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              roleLabel,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.person_outline, color: AppTheme.primary, size: 22),
                                  title: Text(
                                    lang.t('profile.myProfile'),
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context.go(isStudent ? '/student/profile' : '/teacher/profile');
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.logout, color: AppTheme.primary, size: 22),
                                  title: Text(
                                    lang.t('common.logout'),
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  onTap: () async {
                                    await auth.logout();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) context.go('/login');
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
        Material(
          color: Colors.white,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: navItems.map((item) {
                final isActive = location == item.path || location.startsWith('${item.path}/');
                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(item.path),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 24, color: isActive ? AppTheme.primary : Colors.grey),
                          const SizedBox(height: 4),
                          Text(item.label, style: TextStyle(fontSize: 10, color: isActive ? AppTheme.primary : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].length >= 2 ? parts[0].substring(0, 2).toUpperCase() : parts[0].toUpperCase();
  return '${parts[0].isNotEmpty ? parts[0][0] : ''}${parts[1].isNotEmpty ? parts[1][0] : ''}'.toUpperCase();
}

class _NavItem {
  final String path;
  final String label;
  final IconData icon;
  _NavItem({required this.path, required this.label, required this.icon});
}
