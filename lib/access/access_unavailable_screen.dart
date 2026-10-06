import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import 'access_provider.dart';

class AccessUnavailableScreen extends ConsumerWidget {
  const AccessUnavailableScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final he = Localizations.localeOf(context).languageCode == 'he';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  he
                      ? 'לא ניתן לטעון את הרשאות החשבון'
                      : 'Could not load account permissions',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.read(accessProvider.notifier).refresh(),
                  child: Text(he ? 'נסו שוב' : 'Retry'),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  child: Text(he ? 'יציאה מהחשבון' : 'Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
