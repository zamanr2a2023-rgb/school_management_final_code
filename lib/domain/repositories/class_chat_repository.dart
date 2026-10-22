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

  /// Connects socket (if needed), joins class room, and streams new messages.
  Stream<ClassChatMessageEntity> watchMessages(String classId);

  /// Streams message ids removed via moderation (realtime).
  Stream<String> watchDeletedMessageIds(String classId);

  Future<void> leaveRoom(String classId);

  Future<void> disconnectSocket();
}
