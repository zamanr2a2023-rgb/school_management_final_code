import 'package:high_school/data/datasources/class_chat_remote_datasource.dart';
import 'package:high_school/data/datasources/class_chat_socket_client.dart';
import 'package:high_school/domain/entities/class_chat_message_entity.dart';
import 'package:high_school/domain/repositories/class_chat_repository.dart';

class ClassChatRepositoryImpl implements ClassChatRepository {
  ClassChatRepositoryImpl(this._remote, this._socket);

  final ClassChatRemoteDatasource _remote;
  final ClassChatSocketClient _socket;

  @override
  Future<ClassChatRoomEntity?> getRoom(String classId) => _remote.getRoom(classId);

  @override
  Future<ClassChatMessagesPage> getMessages(
    String classId, {
    int limit = 50,
    String? before,
  }) =>
      _remote.getMessages(classId, limit: limit, before: before);

  @override
  Future<ClassChatMessageEntity?> sendMessage(String classId, String text) =>
      _remote.sendMessage(classId, text);

  @override
  Future<void> deleteMessage(String classId, String messageId) =>
      _remote.deleteMessage(classId, messageId);

  @override
  Future<bool> getMuted(String classId) => _remote.getMuted(classId);

  @override
  Future<bool> setMuted(String classId, bool muted) =>
      _remote.setMuted(classId, muted);

  @override
  Stream<ClassChatMessageEntity> watchMessages(String classId) {
    _socket.connectAndJoin(classId);
    return _socket.messages.where((m) => m.classId == classId || classId.isEmpty);
  }

  @override
  Stream<String> watchDeletedMessageIds(String classId) {
    _socket.connectAndJoin(classId);
    return _socket.deletedMessages
        .where((e) => e.classId.isEmpty || e.classId == classId)
        .map((e) => e.id);
  }

  @override
  Future<void> leaveRoom(String classId) => _socket.leave(classId);

  @override
  Future<void> disconnectSocket() => _socket.disconnect();
}
