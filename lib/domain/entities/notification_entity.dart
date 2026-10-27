enum NotificationType { student, admin, system, chat }

class NotificationEntity {
  final String id;
  final NotificationType type;
  final String from;
  final String message;
  final String timestamp;
  final bool read;
  final DateTime sortKey;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.from,
    required this.message,
    required this.timestamp,
    required this.read,
    DateTime? sortKey,
  }) : sortKey = sortKey ?? DateTime.fromMillisecondsSinceEpoch(0);
}
