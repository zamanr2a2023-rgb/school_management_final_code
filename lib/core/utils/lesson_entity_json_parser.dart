import 'package:high_school/domain/entities/lesson_entity.dart';

/// Parses lesson rows from class detail APIs and infers [LessonType] from files when needed.
class LessonEntityJsonParser {
  static Map<String, String>? firstAttachment(Map<String, dynamic> m) {
    for (final key in ['attachments', 'files']) {
      final raw = m[key];
      if (raw is! List || raw.isEmpty) continue;
      final first = raw.first;
      if (first is! Map) continue;
      final fm = Map<String, dynamic>.from(first);
      final url = fm['url']?.toString() ?? fm['path']?.toString() ?? '';
      if (url.isEmpty) continue;
      return {
        'url': url,
        'mime': fm['mimeType']?.toString() ?? fm['mimetype']?.toString() ?? '',
        'name': fm['originalName']?.toString() ?? fm['filename']?.toString() ?? 'file',
      };
    }
    return null;
  }

  static LessonType inferLessonType({
    required String contentTypeRaw,
    String? mime,
    String? name,
    String? url,
  }) {
    final ct = contentTypeRaw.toLowerCase();
    var type = LessonType.text;
    if (ct.contains('video')) {
      type = LessonType.video;
    } else if (ct.contains('pdf')) {
      type = LessonType.pdf;
    }

    final mimeLower = (mime ?? '').toLowerCase();
    final nameLower = (name ?? '').toLowerCase();
    final urlLower = (url ?? '').toLowerCase();

    final isImage = mimeLower.startsWith('image/') ||
        nameLower.endsWith('.jpg') ||
        nameLower.endsWith('.jpeg') ||
        nameLower.endsWith('.png') ||
        nameLower.endsWith('.gif') ||
        nameLower.endsWith('.webp') ||
        nameLower.endsWith('.bmp') ||
        nameLower.endsWith('.heic') ||
        _pathLooksImage(urlLower);

    if (mimeLower.contains('video') || _pathLooksVideo(urlLower) || nameLower.endsWith('.mp4')) {
      return LessonType.video;
    }
    if (mimeLower.contains('pdf') ||
        nameLower.endsWith('.pdf') ||
        _pathLooksPdf(urlLower)) {
      return LessonType.pdf;
    }
    if (isImage && type == LessonType.text) {
      return LessonType.pdf;
    }
    return type;
  }

  static bool _pathLooksPdf(String path) {
    final p = _stripQuery(path);
    return p.endsWith('.pdf');
  }

  static bool _pathLooksVideo(String path) {
    final p = _stripQuery(path);
    return p.endsWith('.mp4') ||
        p.endsWith('.webm') ||
        p.endsWith('.mov') ||
        p.endsWith('.m4v') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  static bool _pathLooksImage(String path) {
    final p = _stripQuery(path);
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.gif') ||
        p.endsWith('.webp') ||
        p.endsWith('.bmp') ||
        p.endsWith('.heic');
  }

  static String _stripQuery(String url) {
    final uri = Uri.tryParse(url);
    return (uri?.path ?? url).toLowerCase();
  }

  static LessonEntity? parse(
    Map<String, dynamic> m,
    String fallbackClassId, {
    String Function(String path)? resolveAssetUrl,
  }) {
    final id = m['_id']?.toString() ?? m['id']?.toString();
    if (id == null || id.isEmpty) return null;

    var classId = m['classId']?.toString() ?? '';
    if (classId.isEmpty) classId = fallbackClassId;

    final title = m['title']?.toString() ?? '';
    final description = m['description']?.toString() ?? '';
    final ct = (m['contentType'] ?? m['type'])?.toString() ?? 'text';

    var content = m['content']?.toString() ?? '';
    if (content.isEmpty) {
      content = m['videoUrl']?.toString() ?? m['video']?.toString() ?? '';
    }

    String? attachmentMime;
    String? attachmentName;
    final firstAtt = firstAttachment(m);
    if (firstAtt != null) {
      if (content.isEmpty) content = firstAtt['url'] ?? '';
      attachmentMime = firstAtt['mime'];
      attachmentName = firstAtt['name'];
    }

    final type = inferLessonType(
      contentTypeRaw: ct,
      mime: attachmentMime,
      name: attachmentName,
      url: content.isNotEmpty ? content : firstAtt?['url'],
    );

    if (content.isNotEmpty &&
        !content.startsWith('http://') &&
        !content.startsWith('https://') &&
        resolveAssetUrl != null) {
      content = resolveAssetUrl(content);
    }

    var dateStr = m['date']?.toString() ?? '';
    if (dateStr.isEmpty) {
      final created = m['createdAt']?.toString();
      if (created != null && created.length >= 10) dateStr = created.substring(0, 10);
    }
    final duration = m['duration']?.toString();
    final statusStr = (m['status']?.toString() ?? 'published').toLowerCase();
    final status = statusStr == 'draft' ? LessonStatus.draft : LessonStatus.published;
    var lastUpdated =
        m['updatedAt']?.toString() ?? m['lastUpdated']?.toString() ?? m['createdAt']?.toString() ?? '';
    if (lastUpdated.length >= 10) lastUpdated = lastUpdated.substring(0, 10);
    if (lastUpdated.isEmpty) lastUpdated = dateStr;
    final module = m['chapter']?.toString() ?? m['module']?.toString();
    final createdByRole = (m['createdBy'] is Map
            ? (m['createdBy'] as Map)['role']
            : m['createdByRole'])
        ?.toString()
        .toLowerCase();
    final uploadedByAdmin = m['uploadedByAdmin'] == true || createdByRole == 'admin';

    return LessonEntity(
      id: id,
      classId: classId,
      title: title.isEmpty ? 'Lesson' : title,
      description: description,
      type: type,
      content: content,
      date: dateStr,
      duration: duration,
      status: status,
      lastUpdated: lastUpdated.isEmpty ? dateStr : lastUpdated,
      module: module,
      attachmentMimeType: attachmentMime,
      attachmentName: attachmentName,
      uploadedByAdmin: uploadedByAdmin,
    );
  }
}
