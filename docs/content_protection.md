# Learning content protection

## What is protected

- In-app **video** (`LessonVideoPlayer`), **PDF** (`TeacherPdfAttachmentScreen`), and **image** (`TeacherLessonImageScreen`) viewers for lessons and assignments that use those screens.
- Android: `FLAG_SECURE` via `screen_protector` while a protected viewer is open.
- iOS: best-effort screenshot mitigation; screen recording / mirroring hides content and pauses video.

## iOS limitations

- Screenshots cannot be fully prevented on iOS.
- Recording and AirPlay mirroring are detected; content is hidden until recording stops.
- YouTube or other WebView embeds may still expose third-party controls.

## Download / share

- Protected PDF viewers no longer show an in-app download action.
- Student lesson PDF flow is view-only in the app.
- Teacher **student submission** download on assignment grading is unchanged.

## Backend security (required for real download control)

Lesson files are served from public `/uploads` static paths. Anyone with the URL can download outside the app.

Recommended follow-up:

1. Remove public static serving; stream through an authenticated API.
2. Return short-lived signed URLs (minutes TTL) after lesson access checks.
3. For high-value video, use HLS with FairPlay / Widevine (e.g. Mux, Cloudflare Stream).

## Manual test checklist

### Android

- [ ] Open video, PDF, and image lesson content — screenshot blocked or black.
- [ ] Screen record shows black on protected screens.
- [ ] Leave viewer — screenshots work on Home / Classes list.

### iOS

- [ ] Start screen recording — overlay appears; video pauses.
- [ ] Stop recording — overlay clears; user can press play again.
- [ ] PDF and image full-screen viewers hide while recording.

### General

- [ ] Playback, PDF pinch-zoom, and image pinch-zoom still work when not recording.
- [ ] No download button on protected PDF viewer.
