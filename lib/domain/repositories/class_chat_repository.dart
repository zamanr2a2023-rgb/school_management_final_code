import 'package:high_school/domain/entities/class_chat_message_entity.dart';

abstract class ClassChatRepository {
  Future<ClassChatRoomEntity?> getRoom(String classId);

  Future<ClassChatMessagesPage> getMessages(
    String classId, {
    int limit = 50,
    String? before,
  });

  Future<ClassChatMessageEntity?> sendMessage(String classId, String text);

  Future<void> deleteMessage(String classId, String messageId);

  Future<bool> getMuted(String classId);

  Future<bool> setMuted(String classId, bool muted);

  Future<int> getUnreadCount(String classId);

  Future<void> markAsRead(String classId);

  /// Connects socket (if needed), joins class room, and streams new messages.
  Stream<ClassChatMessageEntity> watchMessages(String classId);

  /// User-room alerts (`classChat:notify`) — works without joining the class room.
  Stream<ClassChatMessageEntity> watchInAppAlerts();

  /// Streams message ids removed via moderation (realtime).
  Stream<String> watchDeletedMessageIds(String classId);

  Future<void> leaveRoom(String classId);

  Future<void> disconnectSocket();
}
