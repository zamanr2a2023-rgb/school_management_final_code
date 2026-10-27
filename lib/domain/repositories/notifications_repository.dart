import '../entities/notification_entity.dart';

abstract class NotificationsRepository {
  Future<List<NotificationEntity>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();

  /// Persists a class chat alert for the Notifications inbox screen.
  Future<void> recordClassChatNotification({
    required String classId,
    required String title,
    required String body,
    required String messageId,
  });
}
