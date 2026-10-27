import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/domain/entities/notification_entity.dart';
import 'package:high_school/domain/repositories/notifications_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationEntity>? _list;

  Future<void> _load() async {
    final list = await context.read<NotificationsRepository>().getNotifications();
    if (mounted) setState(() => _list = list);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (_list == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = _list!;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page heading – match React (text-xl font-semibold)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            lang.t('notifications.notifications'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (list.isNotEmpty) ...[
          // Mark all read – optional, React doesn't show it in the snippet but Flutter had it
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await context.read<NotificationsRepository>().markAllAsRead();
                await _load();
              },
              child: Text(lang.t('notifications.markAllRead')),
            ),
          ),
          const SizedBox(height: 8),
          ...list.map((n) => _NotificationCard(
                notification: n,
                lang: lang,
                onTap: () async {
                  await context.read<NotificationsRepository>().markAsRead(n.id);
                  await _load();
                },
              )),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                lang.t('notifications.noNotifications'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
        ),
      ),
    );
  }
}

Color _avatarColor(NotificationType type) {
  switch (type) {
    case NotificationType.student:
      return const Color(0xFFE91E63); // pink
    case NotificationType.admin:
      return AppTheme.accent;
    case NotificationType.system:
      return AppTheme.secondary;
    case NotificationType.chat:
      return AppTheme.primary;
  }
}

String _initials(String from) {
  return from
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .map((s) => s.isNotEmpty ? s[0] : '')
      .take(2)
      .join()
      .toUpperCase();
}

class _NotificationCard extends StatelessWidget {
  final NotificationEntity notification;
  final LanguageProvider lang;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _avatarColor(notification.type),
                  child: Text(
                    _initials(notification.from),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.from,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                notification.timestamp,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (!notification.read) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
