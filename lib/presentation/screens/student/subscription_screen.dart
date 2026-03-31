import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/subscription_provider.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final subscription = context.watch<SubscriptionProvider>();

    return FutureBuilder(
      future: auth.user != null ? subscription.load(auth.user!.id) : Future.value(),
      builder: (context, _) {
        final sub = subscription.subscription;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sub != null)
              Card(
                child: ListTile(
                  title: const Text('Current subscription'),
                  subtitle: Text('Active until ${sub.endDate}'),
                ),
              ),
            if (sub == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No active subscription.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                ),
              ),
          ],
        );
      },
    );
  }
}
