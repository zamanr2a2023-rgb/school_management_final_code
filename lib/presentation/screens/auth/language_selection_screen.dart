import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/presentation/widgets/garini_logo.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/core/l10n/app_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final languages = [
      _LangOption(code: AppLanguage.en, name: 'English', nativeName: 'English', flag: '🇬🇧'),
      _LangOption(code: AppLanguage.fr, name: 'French', nativeName: 'Français', flag: '🇫🇷'),
      _LangOption(code: AppLanguage.ar, name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦'),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GariniLogo(size: 100, fit: BoxFit.contain, fallbackColor: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Online Learning Platform', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 32),
              Text('Choose Your Language', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              ...languages.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: lang.language == l.code ? AppTheme.primary.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () async {
                      await lang.setLanguage(l.code);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(AppConstants.languageSelectedKey, true);
                      if (context.mounted) context.go('/login');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Text(l.flag, style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                Text(l.nativeName, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              ],
                            ),
                          ),
                          if (lang.language == l.code) const Icon(Icons.check, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangOption {
  final AppLanguage code;
  final String name;
  final String nativeName;
  final String flag;
  _LangOption({required this.code, required this.name, required this.nativeName, required this.flag});
}
