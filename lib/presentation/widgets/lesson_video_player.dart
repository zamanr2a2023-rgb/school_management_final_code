import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:high_school/core/security/content_protection_service.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Inline lesson video: direct files via [Chewie], YouTube/other embeds via WebView.
class LessonVideoPlayer extends StatefulWidget {
  const LessonVideoPlayer({super.key, required this.url});

  final String url;

  @override
  State<LessonVideoPlayer> createState() => _LessonVideoPlayerState();
}

class _LessonVideoPlayerState extends State<LessonVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  WebViewController? _webController;
  bool _loading = true;
  String? _error;
  bool _useWebView = false;

  @override
  void initState() {
    super.initState();
    ContentProtectionService.captureBlockingActive.addListener(_onCaptureBlockingChanged);
    _initPlayer();
  }

  void _onCaptureBlockingChanged() {
    if (!ContentProtectionService.captureBlockingActive.value) return;
    _videoController?.pause();
    _chewieController?.pause();
  }

  Future<void> _initPlayer() async {
    final url = widget.url.trim();
    if (url.isEmpty) {
      _setError('No video URL');
      return;
    }

    final youtubeEmbed = _youTubeEmbedUrl(url);
    if (youtubeEmbed != null) {
      _initWebView(youtubeEmbed);
      return;
    }

    await _initDirectPlayer(url);
  }

  void _initWebView(String pageUrl) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF111827))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (mounted && _loading) {
              setState(() {
                _loading = false;
                _error = e.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(pageUrl));

    setState(() {
      _useWebView = true;
      _webController = controller;
      _loading = true;
      _error = null;
    });
  }

  Future<void> _initDirectPlayer(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _initWebView(url);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        showOptions: false,
        aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue.shade400,
          handleColor: Colors.blue.shade600,
          bufferedColor: Colors.grey.shade600,
          backgroundColor: Colors.grey.shade800,
        ),
        placeholder: const ColoredBox(
          color: Color(0xFF111827),
          child: Center(child: CircularProgressIndicator(color: Colors.white70)),
        ),
        errorBuilder: (context, message) => _errorContent(message),
      );
      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      _initWebView(url);
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  static String? _youTubeEmbedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (!host.contains('youtube.com') && !host.contains('youtu.be')) return null;

    String? id;
    if (host.contains('youtu.be')) {
      if (uri.pathSegments.isNotEmpty) id = uri.pathSegments.first;
    } else if (uri.pathSegments.contains('embed') && uri.pathSegments.length > 1) {
      id = uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
    } else {
      id = uri.queryParameters['v'];
    }
    if (id == null || id.isEmpty) return null;
    return 'https://www.youtube.com/embed/$id?playsinline=1&rel=0';
  }

  @override
  void dispose() {
    ContentProtectionService.captureBlockingActive.removeListener(_onCaptureBlockingChanged);
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _errorContent(_error!);
    }
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFF111827),
        child: Center(child: CircularProgressIndicator(color: Colors.white70)),
      );
    }
    if (_useWebView && _webController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: WebViewWidget(controller: _webController!),
      );
    }
    if (_chewieController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Chewie(controller: _chewieController!),
      );
    }
    return _errorContent('Unable to load video');
  }

  Widget _errorContent(String message) {
    return ColoredBox(
      color: const Color(0xFF111827),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
