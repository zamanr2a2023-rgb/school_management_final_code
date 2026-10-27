import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/services/push_notification_service.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/data/datasources/class_chat_remote_datasource.dart';
import 'package:high_school/domain/entities/class_chat_message_entity.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/domain/repositories/class_chat_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class ClassChatScreen extends StatefulWidget {
  const ClassChatScreen({
    super.key,
    required this.classId,
    this.className,
    this.backPath,
  });

  final String classId;
  final String? className;
  final String? backPath;

  @override
  State<ClassChatScreen> createState() => _ClassChatScreenState();
}

class _ClassChatScreenState extends State<ClassChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ClassChatMessageEntity> _messages = [];

  StreamSubscription<ClassChatMessageEntity>? _socketSub;
  StreamSubscription<String>? _deletedSub;
  ClassChatRepository? _repo;
  PushNotificationService? _push;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _hasMore = false;
  bool _muted = false;
  bool _muteBusy = false;
  String? _nextBefore;
  String? _title;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = widget.className;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final repo = context.read<ClassChatRepository>();
    _repo = repo;
    try {
      _push = context.read<PushNotificationService>();
      _push!.activeClassChatId = widget.classId;
    } catch (_) {
      _push = null;
    }
    try {
      final room = await repo.getRoom(widget.classId);
      if (!mounted) return;
      if (room != null) {
        setState(() => _title = room.className);
      }

      final muted = await repo.getMuted(widget.classId);
      if (!mounted) return;

      final page = await repo.getMessages(widget.classId);
      if (!mounted) return;
      setState(() {
        _muted = muted;
        _messages
          ..clear()
          ..addAll(page.messages);
        _hasMore = page.hasMore;
        _nextBefore = page.nextBefore;
        _loading = false;
        _error = null;
      });
      _scrollToBottom(force: true);

      // Opening the chat clears the unread badge for this class.
      unawaited(repo.markAsRead(widget.classId));

      await _socketSub?.cancel();
      await _deletedSub?.cancel();
      _socketSub = repo.watchMessages(widget.classId).listen(_onIncoming);
      _deletedSub =
          repo.watchDeletedMessageIds(widget.classId).listen(_onDeleted);
    } on ClassChatAccessException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _goBack();
      });
    } catch (_) {
      if (!mounted) return;
      final lang = context.read<LanguageProvider>();
      setState(() {
        _loading = false;
        _error = _t(lang, 'chat.loadFailed', 'Failed to load chat');
      });
    }
  }

  void _onIncoming(ClassChatMessageEntity msg) {
    if (msg.classId != widget.classId) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    final tempIdx = _messages.indexWhere(
      (m) =>
          m.id.startsWith('temp_') &&
          m.senderId == msg.senderId &&
          m.text == msg.text,
    );
    final wasReplace = tempIdx >= 0;
    setState(() {
      if (tempIdx >= 0) {
        _messages[tempIdx] = msg;
      } else {
        _messages.add(msg);
      }
    });
    _scrollToBottom();

    // Keep unread cursor current while the chat is open.
    if (!wasReplace) {
      unawaited(_repo?.markAsRead(widget.classId) ?? Future.value());
    }
  }

  void _onDeleted(String messageId) {
    if (messageId.isEmpty) return;
    setState(() {
      _messages.removeWhere((m) => m.id == messageId);
    });
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 80) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_nextBefore == null || _nextBefore!.isEmpty) return;
    setState(() => _loadingMore = true);
    final repo = context.read<ClassChatRepository>();
    final older = await repo.getMessages(
      widget.classId,
      before: _nextBefore,
    );
    if (!mounted) return;
    final existingIds = _messages.map((m) => m.id).toSet();
    final toPrepend =
        older.messages.where((m) => !existingIds.contains(m.id)).toList();
    final prevMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    setState(() {
      _messages.insertAll(0, toPrepend);
      _hasMore = older.hasMore;
      _nextBefore = older.nextBefore;
      _loadingMore = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final newMax = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(newMax - prevMax);
    });
  }

  Future<void> _toggleMute() async {
    if (_muteBusy) return;
    final lang = context.read<LanguageProvider>();
    final next = !_muted;
    setState(() => _muteBusy = true);
    try {
      final muted =
          await context.read<ClassChatRepository>().setMuted(widget.classId, next);
      if (!mounted) return;
      setState(() => _muted = muted);
      if (!muted) {
        // Confirm sound works when user unmutes.
        await _push?.playChatSound();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            muted
                ? _t(lang, 'chat.muted', 'Notifications muted for this class')
                : _t(
                    lang,
                    'chat.unmuted',
                    'Notifications unmuted — you will hear new messages',
                  ),
          ),
        ),
      );
    } on ClassChatApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(lang, 'chat.muteFailed', 'Failed to update mute'))),
      );
    } finally {
      if (mounted) setState(() => _muteBusy = false);
    }
  }

  Future<void> _confirmDelete(ClassChatMessageEntity msg) async {
    final lang = context.read<LanguageProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(lang, 'chat.deleteTitle', 'Delete message')),
        content: Text(
          _t(
            lang,
            'chat.deleteConfirm',
            'Delete this message? Everyone in the class will no longer see it.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(lang, 'chat.cancel', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t(lang, 'chat.delete', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await context
          .read<ClassChatRepository>()
          .deleteMessage(widget.classId, msg.id);
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == msg.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(lang, 'chat.deleted', 'Message deleted'))),
      );
    } on ClassChatAccessException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ClassChatApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(lang, 'chat.deleteFailed', 'Failed to delete message')),
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 2000) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(lang, 'chat.tooLong', 'Message is too long')),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ClassChatMessageEntity(
      id: tempId,
      classId: widget.classId,
      senderId: user?.id ?? '',
      senderName: user?.name ?? 'You',
      senderRole: user?.role.name ?? 'student',
      text: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _sending = true;
      _messages.add(optimistic);
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final repo = context.read<ClassChatRepository>();
      final saved = await repo.sendMessage(widget.classId, text);
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          final i = _messages.indexWhere((m) => m.id == tempId);
          if (i >= 0) {
            _messages[i] = saved;
          } else if (!_messages.any((m) => m.id == saved.id)) {
            _messages.add(saved);
          }
        });
      }
    } on ClassChatAccessException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _goBack();
    } on ClassChatApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      final lang = context.read<LanguageProvider>();
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(lang, 'chat.sendFailed', 'Failed to send'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (!force && pos.maxScrollExtent - pos.pixels > 120) return;
      _scrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _goBack() {
    if (widget.backPath != null && widget.backPath!.isNotEmpty) {
      context.go(widget.backPath!);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  String _t(LanguageProvider lang, String key, String fallback) {
    final s = lang.t(key);
    return (s == key || s.isEmpty) ? fallback : s;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _socketSub?.cancel();
    _deletedSub?.cancel();
    if (_push?.activeClassChatId == widget.classId) {
      _push!.activeClassChatId = null;
    }
    _repo?.leaveRoom(widget.classId);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<AuthProvider>().user;
    final myId = user?.id ?? '';
    final canModerate = user?.role == UserRole.teacher;
    final title = _title?.isNotEmpty == true
        ? _title!
        : _t(lang, 'chat.title', 'Class Chat');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          IconButton(
            tooltip: _muted
                ? _t(lang, 'chat.unmute', 'Unmute notifications')
                : _t(lang, 'chat.mute', 'Mute notifications'),
            onPressed: _muteBusy ? null : _toggleMute,
            icon: Icon(_muted ? Icons.notifications_off : Icons.notifications_active),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingMore) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                    ? Center(child: Text(_error!))
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              _t(lang, 'chat.empty', 'No messages yet. Say hello!'),
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            itemCount: _messages.length + (!_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (!_hasMore && index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Center(
                                    child: Text(
                                      _t(
                                        lang,
                                        'chat.historyEnd',
                                        'Beginning of conversation',
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final msgIndex = !_hasMore ? index - 1 : index;
                              final msg = _messages[msgIndex];
                              final isMine = msg.senderId == myId;
                              final roleLabel = msg.isTeacher
                                  ? _t(lang, 'chat.roleTeacher', 'Teacher')
                                  : _t(lang, 'chat.roleStudent', 'Student');
                              return _ChatBubble(
                                message: msg,
                                isMine: isMine,
                                roleLabel: roleLabel,
                                canDelete: canModerate && !msg.id.startsWith('temp_'),
                                onDelete: () => _confirmDelete(msg),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _t(lang, 'chat.hint', 'Type a message...'),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.roleLabel,
    required this.canDelete,
    required this.onDelete,
  });

  final ClassChatMessageEntity message;
  final bool isMine;
  final String roleLabel;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final local = message.createdAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final senderName =
        message.senderName.trim().isEmpty ? 'User' : message.senderName.trim();

    final bubble = Align(
      alignment: isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      message.isTeacher
                          ? Icons.school_rounded
                          : Icons.person_outline_rounded,
                      size: 14,
                      color: message.isTeacher
                          ? AppTheme.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: message.isTeacher ? 13 : 12,
                          fontWeight: message.isTeacher
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: message.isTeacher
                              ? AppTheme.primary
                              : Colors.grey.shade700,
                          fontStyle: message.isTeacher
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: message.isTeacher
                            ? AppTheme.primary.withValues(alpha: 0.14)
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: message.isTeacher
                              ? AppTheme.primary.withValues(alpha: 0.35)
                              : AppTheme.accent.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: message.isTeacher
                              ? AppTheme.primary
                              : AppTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMine ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: const Radius.circular(14),
                    topEnd: const Radius.circular(14),
                    bottomStart: Radius.circular(isMine ? 14 : 4),
                    bottomEnd: Radius.circular(isMine ? 4 : 14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!canDelete) return bubble;

    return GestureDetector(
      onLongPress: onDelete,
      child: bubble,
    );
  }
}
