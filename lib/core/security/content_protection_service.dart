import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Platform screen capture protection for lesson media viewers.
///
/// Use [push] / [pop] with matching [ProtectedContentScope] lifecycles.
/// Ref-counted so nested viewers do not disable protection early.
///
/// Backend note: client protection cannot stop direct HTTP GET to public `/uploads`
/// URLs. Use short-lived signed URLs and private storage for real download control.
class ContentProtectionService {
  ContentProtectionService._();

  static int _depth = 0;
  static bool _listenerRegistered = false;

  /// True while iOS screen recording / mirroring is active (also updated on resume).
  static final ValueNotifier<bool> captureBlockingActive = ValueNotifier(false);

  static Future<void> push() async {
    _depth++;
    if (_depth > 1) return;
    await _enablePlatform();
    await _refreshCaptureState();
    _registerIosListener();
  }

  static Future<void> pop() async {
    if (_depth == 0) return;
    _depth--;
    if (_depth > 0) return;
    _unregisterIosListener();
    captureBlockingActive.value = false;
    await _disablePlatform();
  }

  static Future<void> onAppResumed() async {
    if (_depth == 0) return;
    await _enablePlatform();
    await _refreshCaptureState();
  }

  static Future<void> _enablePlatform() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
      } else if (Platform.isIOS) {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageWithBlur();
      }
    } catch (e, st) {
      debugPrint('ContentProtectionService enable: $e\n$st');
    }
  }

  static Future<void> _disablePlatform() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOff();
      } else if (Platform.isIOS) {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageWithBlurOff();
      }
    } catch (e, st) {
      debugPrint('ContentProtectionService disable: $e\n$st');
    }
  }

  static Future<void> _refreshCaptureState() async {
    if (kIsWeb || !Platform.isIOS) {
      captureBlockingActive.value = false;
      return;
    }
    try {
      final recording = await ScreenProtector.isRecording();
      captureBlockingActive.value = recording;
    } catch (e, st) {
      debugPrint('ContentProtectionService isRecording: $e\n$st');
    }
  }

  static void _registerIosListener() {
    if (kIsWeb || !Platform.isIOS || _listenerRegistered) return;
    _listenerRegistered = true;
    ScreenProtector.addListener(
      null,
      (bool isCaptured) {
        captureBlockingActive.value = isCaptured;
      },
    );
  }

  static void _unregisterIosListener() {
    if (!_listenerRegistered) return;
    _listenerRegistered = false;
    try {
      ScreenProtector.removeListener();
    } catch (e, st) {
      debugPrint('ContentProtectionService removeListener: $e\n$st');
    }
  }
}
