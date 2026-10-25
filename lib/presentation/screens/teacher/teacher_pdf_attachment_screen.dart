import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/widgets/protected_content_scope.dart';

/// Saves [url] to app documents and opens it with the system viewer.
Future<void> downloadTeacherPdfAttachment(
  BuildContext context,
  String url,
  String fileName,
) async {
  final lang = context.read<LanguageProvider>();
  void showMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final dir = await getApplicationDocumentsDirectory();
    final safe = _safePdfFileName(fileName);
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    showMessage(lang.t('assignments.pdfDownloaded'));
    await OpenFilex.open(file.path);
  } catch (e) {
    showMessage(lang.t('assignments.pdfDownloadFailed'));
  }
}

String _safePdfFileName(String name) {
  var n = name.trim();
  if (n.isEmpty) n = 'document.pdf';
  n = n.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  if (!n.toLowerCase().endsWith('.pdf')) {
    n = '$n.pdf';
  }
  return n;
}

/// Full-screen PDF from a remote URL (e.g. assignment attachment).
class TeacherPdfAttachmentScreen extends StatefulWidget {
  const TeacherPdfAttachmentScreen({
    super.key,
    required this.url,
    required this.fileName,
  });

  final String url;
  final String fileName;

  @override
  State<TeacherPdfAttachmentScreen> createState() => _TeacherPdfAttachmentScreenState();
}

class _TeacherPdfAttachmentScreenState extends State<TeacherPdfAttachmentScreen> {
  Object? _error;
  PdfControllerPinch? _controller;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _error = null;
      _controller?.dispose();
      _controller = null;
    });
    try {
      final uri = Uri.parse(widget.url);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final data = response.bodyBytes;
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(
          document: PdfDocument.openData(data),
        );
      });
    } catch (e, st) {
      debugPrint('TeacherPdfAttachmentScreen load error: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return ProtectedContentScope(
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 16),
                    Text(
                      lang.t('assignments.pdfOpenFailed'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadPdf,
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                      child: Text(lang.t('common.retry')),
                    ),
                  ],
                ),
              ),
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : PdfViewPinch(
                  controller: _controller!,
                ),
      ),
    );
  }
}
