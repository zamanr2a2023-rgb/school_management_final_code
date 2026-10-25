import 'package:flutter/material.dart';
import 'package:high_school/core/security/content_protection_service.dart';
import 'package:provider/provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

/// Wraps protected lesson media (video, PDF, image) with platform capture
/// protection and an iOS recording/mirroring overlay.
class ProtectedContentScope extends StatefulWidget {
  const ProtectedContentScope({
    super.key,
    required this.child,
    this.onCaptureBlockingChanged,
  });

  final Widget child;

  /// Called when iOS recording/mirroring blocks content (e.g. pause video).
  final void Function(bool isBlocking)? onCaptureBlockingChanged;

  @override
  State<ProtectedContentScope> createState() => _ProtectedContentScopeState();
}

class _ProtectedContentScopeState extends State<ProtectedContentScope>
    with WidgetsBindingObserver {
  bool _blocking = false;

  @override
  void initState() {
    super.initState();
    _blocking = ContentProtectionService.captureBlockingActive.value;
    WidgetsBinding.instance.addObserver(this);
    ContentProtectionService.captureBlockingActive.addListener(_onBlockingChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ContentProtectionService.push();
    });
  }

  @override
  void dispose() {
    ContentProtectionService.captureBlockingActive.removeListener(_onBlockingChanged);
    WidgetsBinding.instance.removeObserver(this);
    ContentProtectionService.pop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ContentProtectionService.onAppResumed();
    }
  }

  void _onBlockingChanged() {
    final next = ContentProtectionService.captureBlockingActive.value;
    if (_blocking == next) return;
    setState(() => _blocking = next);
    widget.onCaptureBlockingChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_blocking)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF111827),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off_outlined,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lang.t('contentProtection.recordingBlocked'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
