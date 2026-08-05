import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../settings/settings_controller.dart';

/// Wraps the app and blocks access behind the phone's own screen lock
/// (fingerprint, face, pattern or PIN) when app-lock is enabled (Section 16).
///
/// We deliberately do not keep our own PIN. We hand off to the device's
/// existing security via [LocalAuthentication] with `biometricOnly: false`, so
/// whatever the user already trusts to unlock their phone unlocks the app too.
/// Unlock persists for the session only.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authInProgress = false;
  bool _autoPrompted = false;
  String? _error;

  /// When the app was last backgrounded. Used to re-lock on resume: brief
  /// task-switches (under [_relockGrace]) don't force re-auth so the experience
  /// stays calm, but leaving the app for longer re-locks it. Previously an
  /// unlock persisted for the whole process lifetime, even across backgrounding.
  DateTime? _backgroundedAt;
  static const Duration _relockGrace = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      final away = backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(backgroundedAt);
      if (mounted && _unlocked && away >= _relockGrace) {
        setState(() {
          _unlocked = false;
          _autoPrompted = false;
          _error = null;
        });
      }
    }
  }

  Future<void> _authenticate() async {
    if (_authInProgress) return;
    _authInProgress = true;
    setState(() => _error = null);

    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Unlock BudgetSense',
        options: const AuthenticationOptions(
          stickyAuth: true,
          // Allow the device PIN / pattern / password to be used alongside
          // biometrics, so users without enrolled biometrics can still unlock.
          biometricOnly: false,
        ),
      );
      if (!mounted) return;
      setState(() {
        _unlocked = ok;
        _error = ok ? null : 'Unlock cancelled. Tap below to try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _error = "Couldn't verify with your device lock. Tap to try again.",
      );
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;

    final locked = settings != null && settings.appLockEnabled && !_unlocked;
    if (!locked) return widget.child;

    // Prompt the device unlock automatically the first time we're shown.
    if (!_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }

    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Material(
      color: colors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_outline, size: 40, color: colors.accent),
              const SizedBox(height: Insets.lg),
              Text(
                'BudgetSense is locked',
                style: text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Use your fingerprint, face, pattern or PIN to unlock.',
                style: text.bodyMedium?.copyWith(color: colors.textFaint),
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.md),
                Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: colors.critical),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: Insets.xl),
              FilledButton.icon(
                onPressed: _authInProgress ? null : _authenticate,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
