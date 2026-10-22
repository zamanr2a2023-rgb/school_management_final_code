class ClassChatMessageEntity {
  const ClassChatMessageEntity({
    required this.id,
    required this.classId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime createdAt;

  bool get isTeacher => senderRole.toLowerCase() == 'teacher';

  factory ClassChatMessageEntity.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'];
    DateTime createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else if (createdRaw is DateTime) {
      createdAt = createdRaw;
    } else if (createdRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdRaw);
    } else {
      createdAt = DateTime.now();
    }

    final role = (json['senderRole'] ?? json['role'] ?? 'student')
        .toString()
        .trim()
        .toLowerCase();

    return ClassChatMessageEntity(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      classId: (json['classId'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['sender'] ?? '').toString(),
      senderName: (json['senderName'] ?? json['name'] ?? 'User').toString(),
      senderRole: role.isEmpty ? 'student' : role,
      text: (json['text'] ?? json['message'] ?? '').toString(),
      createdAt: createdAt,
    );
  }
}

class ClassChatRoomEntity {
  const ClassChatRoomEntity({
    required this.classId,
    required this.className,
    this.subject = '',
    this.gradeLevel = '',
    this.memberCount = 0,
  });

  final String classId;
  final String className;
  final String subject;
  final String gradeLevel;
  final int memberCount;

  factory ClassChatRoomEntity.fromJson(Map<String, dynamic> json) {
    return ClassChatRoomEntity(
      classId: (json['classId'] ?? '').toString(),
      className: (json['className'] ?? 'Class').toString(),
      subject: (json['subject'] ?? '').toString(),
      gradeLevel: (json['gradeLevel'] ?? '').toString(),
      memberCount: int.tryParse('${json['memberCount'] ?? 0}') ?? 0,
    );
  }
}

class ClassChatMessagesPage {
  const ClassChatMessagesPage({
    required this.messages,
    required this.hasMore,
    this.nextBefore,
  });

  final List<ClassChatMessageEntity> messages;
  final bool hasMore;
  final String? nextBefore;
}
