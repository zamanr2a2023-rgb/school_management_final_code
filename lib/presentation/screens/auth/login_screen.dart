import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/presentation/widgets/garini_logo.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/widgets/language_selector_widget.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginBody();
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final auth = context.read<AuthProvider>();
    final phone = _phoneController.text.trim();
    final pin = _pinController.text;

    if (phone.isEmpty) {
      setState(() {
        _error = 'Please provide a phone number';
        _loading = false;
      });
      return;
    }

    final ok = await auth.login(phone, pin);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      final user = auth.user!;
      if (user.role.name == 'student') {
        context.go('/student/dashboard');
      } else {
        context.go('/teacher/dashboard');
      }
    } else {
      setState(() => _error = auth.lastAuthError ?? 'Invalid credentials or account not approved yet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Full-width dark blue header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                ),
                child: Column(
                  children: [
                    const GariniLogo(size: 96, fit: BoxFit.contain),
                    const SizedBox(height: 16),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang.t('auth.loginSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Form section on white
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.t('auth.selectLanguage'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const LanguageSelectorWidget(),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Text(
                      lang.t('auth.phoneNumber'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        hintText: 'XX XX XX XX',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      lang.t('auth.pin'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pinController,
                      decoration: InputDecoration(
                        hintText: lang.t('auth.pin'),
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_forward, size: 20),
                        label: Text(lang.t('auth.loginButton')),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lang.t('auth.noAccount'),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
                                ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppTheme.primary,
                            ),
                            child: Text(lang.t('auth.register')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
