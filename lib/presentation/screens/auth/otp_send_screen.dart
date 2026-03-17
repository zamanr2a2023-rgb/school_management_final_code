import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';

class OtpSendScreen extends StatefulWidget {
  const OtpSendScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpSendScreen> createState() => _OtpSendScreenState();
}

class _OtpSendScreenState extends State<OtpSendScreen> {
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _send();
  }

  Future<void> _send() async {
    if (widget.phone.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(widget.phone);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = ok;
      _error = ok ? null : (auth.lastAuthError ?? 'Failed to send OTP');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify phone')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'We are sending a 4-digit OTP to:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.phone,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_sent)
                Text(
                  'OTP sent successfully. Please check your SMS.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        context.go('/otp/verify', extra: widget.phone);
                      },
                child: const Text('Continue'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _send,
                child: const Text('Resend OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

