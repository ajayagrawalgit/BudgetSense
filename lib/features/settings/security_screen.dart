import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/theme/app_spacing.dart';
import '../common/app_feedback.dart';
import '../common/calm_widgets.dart';
import 'settings_controller.dart';

/// App-lock security settings (Section 16). Instead of a separate in-app PIN,
/// BudgetSense reuses the phone's own screen lock (fingerprint, face, pattern
/// or PIN). Turning the toggle on verifies it works once, so the user is never
/// locked out.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);
    final text = Theme.of(context).textTheme;

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            CalmCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App lock'),
                subtitle: const Text(
                  'Require your device unlock (fingerprint, pattern or PIN) '
                  'when opening BudgetSense',
                ),
                value: settings.appLockEnabled,
                onChanged: (v) async {
                  if (v) {
                    final ok = await _confirmDeviceLock(context);
                    if (!ok) return;
                  }
                  await controller.save((c) => c.copyWith(appLockEnabled: v));
                },
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'BudgetSense never stores a PIN of its own. It simply asks Android '
              'to confirm it\'s really you, using the same lock you already '
              'trust on your phone. Nothing is uploaded or written to logs.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Confirms the device has a usable lock and that the user can pass it right
  /// now, so enabling app-lock can never strand them at a dead lock screen.
  Future<bool> _confirmDeviceLock(BuildContext context) async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      if (!supported) {
        if (context.mounted) {
          _snack(
            context,
            'No screen lock found. Set a fingerprint, pattern or PIN in your '
            'phone settings first.',
          );
        }
        return false;
      }
      final ok = await auth.authenticate(
        localizedReason: 'Confirm it\'s you to turn on app lock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (!ok && context.mounted) {
        _snack(context, 'App lock not enabled. Verification was cancelled.');
      }
      return ok;
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Couldn\'t verify your device lock. Please try again.');
      }
      return false;
    }
  }

  void _snack(BuildContext context, String message) {
    context.showMessage(message);
  }
}
