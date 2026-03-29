import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/l10n/app_translations.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class LanguageSelectorWidget extends StatelessWidget {
  const LanguageSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final current = lang.language;

    const lightBlueBorder = Color(0xFFB8D4F0);
    const capsuleRadius = 10.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLanguageMenu(context, lang),
        borderRadius: BorderRadius.circular(capsuleRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(capsuleRadius),
            border: Border.all(color: lightBlueBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: lightBlueBorder.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.language, color: Colors.grey.shade700, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade700, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageMenu(BuildContext context, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _LanguageMenu(lang: lang),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  final LanguageProvider lang;

  const _LanguageMenu({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values
              .map((l) => ListTile(
                    title: Text(l.displayName),
                    onTap: () {
                      lang.setLanguage(l);
                      Navigator.of(context).pop();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}
