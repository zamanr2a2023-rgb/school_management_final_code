import 'package:flutter/material.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/presentation/widgets/lesson_video_player.dart';
import 'package:high_school/presentation/widgets/protected_content_scope.dart';

/// Full-screen in-app video for teacher lesson attachments.
class TeacherLessonVideoScreen extends StatelessWidget {
  const TeacherLessonVideoScreen({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ProtectedContentScope(
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LessonVideoPlayer(url: url),
          ),
        ),
      ),
    );
  }
}

/// Full-screen image preview for lesson attachments (e.g. JPEG).
class TeacherLessonImageScreen extends StatelessWidget {
  const TeacherLessonImageScreen({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ProtectedContentScope(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              width: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
