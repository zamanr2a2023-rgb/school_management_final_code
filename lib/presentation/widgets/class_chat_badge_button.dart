import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/domain/entities/class_chat_message_entity.dart';
import 'package:high_school/domain/repositories/class_chat_repository.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';

/// Chat icon with a red unread count badge for a class.
class ClassChatBadgeButton extends StatefulWidget {
  const ClassChatBadgeButton({
    super.key,
    required this.classId,
    required this.chatPath,
    this.className,
    this.tooltip,
    this.iconColor = Colors.white,
    this.iconSize = 24,
    this.backgroundColor,
    this.padding,
    this.constraints,
  });

  final String classId;
  final String chatPath;
  final String? className;
  final String? tooltip;
  final Color iconColor;
  final double iconSize;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  @override
  State<ClassChatBadgeButton> createState() => _ClassChatBadgeButtonState();
}

class _ClassChatBadgeButtonState extends State<ClassChatBadgeButton> {
  StreamSubscription<ClassChatMessageEntity>? _socketSub;
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final repo = context.read<ClassChatRepository>();
    try {
      final count = await repo.getUnreadCount(widget.classId);
      if (!mounted) return;
      setState(() {
        _unread = count;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }

    await _socketSub?.cancel();
    _socketSub = repo.watchMessages(widget.classId).listen(_onIncoming);
  }

  void _onIncoming(ClassChatMessageEntity msg) {
    if (msg.classId != widget.classId) return;
    final myId = context.read<AuthProvider>().user?.id ?? '';
    if (myId.isNotEmpty && msg.senderId == myId) return;
    if (!mounted) return;
    setState(() => _unread += 1);
  }

  Future<void> _openChat() async {
    await context.push(widget.chatPath, extra: widget.className);
    if (!mounted) return;
    // Chat screen marks as read; refresh badge after returning.
    try {
      final count =
          await context.read<ClassChatRepository>().getUnreadCount(widget.classId);
      if (!mounted) return;
      setState(() => _unread = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unread = 0);
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  String get _badgeLabel {
    if (_unread <= 0) return '';
    if (_unread > 99) return '99+';
    return '$_unread';
  }

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: widget.tooltip,
      onPressed: _openChat,
      icon: Badge(
        isLabelVisible: !_loading && _unread > 0,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        label: Text(
          _badgeLabel,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        child: Icon(
          Icons.chat_bubble_outline,
          color: widget.iconColor,
          size: widget.iconSize,
        ),
      ),
      padding: widget.padding,
      constraints: widget.constraints,
    );

    final bg = widget.backgroundColor;
    if (bg == null) return button;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: button,
    );
  }
}
