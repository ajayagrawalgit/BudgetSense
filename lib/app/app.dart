import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/reminder_messages.dart';
import '../core/services/screen_security_service.dart';
import '../core/services/widget_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_fonts.dart';
import '../core/theme/paper_texture.dart';
import '../core/theme/theme_resolver.dart';
import '../core/utils/haptics.dart';
import '../features/quick_add/quick_add_sheet.dart';
import '../features/security/app_lock_gate.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_state.dart';
import '../features/widgets/widget_sync.dart';
import 'cloud_providers.dart';
import 'feature_providers.dart';
import 'router.dart';
import 'update_providers.dart';

/// Default note stamped on expenses added via the home-screen widget when the
/// user leaves the notes blank. Handled silently in the background.
const kWidgetQuickAddNote = 'Expense Added through BudgetSense Widget';

/// Root widget. Wires settings -> theme and hands routing to go_router.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Actions arriving while the app is already open.
    WidgetService.setActionListener(_handleWidgetAction);
    // An action that launched the app cold.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final action = await WidgetService.consumeLaunchAction();
      if (action != null) _handleWidgetAction(action);
      // Restore cloud sync state and retry any pending upload. No-op (and no
      // network) unless the user previously enabled cloud backup.
      try {
        await ref.read(cloudSyncControllerProvider).loadOnStart();
      } catch (_) {
        // Cloud restore-on-start must never crash launch.
      }
      // Quietly check for an app update (sideloaded builds). Silent and
      // non-blocking: it shows a dismissible banner only if one is available
      // and not already dismissed, and never throws.
      try {
        await ref.read(updateServiceProvider).checkForUpdate();
      } catch (_) {
        // An update check must never crash launch.
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetService.setActionListener(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retry a pending backup when the app returns to the foreground. Cheap and
    // safe: syncNow returns immediately unless cloud backup is on and pending.
    if (state == AppLifecycleState.resumed) {
      final controller = ref.read(cloudSyncControllerProvider);
      if (controller.state.enabled && controller.state.pending) {
        unawaited(controller.syncNow());
      }
    }
  }

  bool _quickAddOpen = false;
  bool _remindersBootstrapped = false;
  bool _recurringCaughtUp = false;
  bool? _appliedScreenSecurity;

  /// Re-arms the "record your expenses" nudge on launch. Running on each cold
  /// start refreshes the rolling window and rotates the messages, so reminders
  /// keep flowing (and vary) even between rare app opens.
  Future<void> _bootstrapDailyReminders(SettingsState settings) async {
    if (!settings.notificationsEnabled ||
        !settings.dailyRecordRemindersEnabled) {
      return;
    }
    try {
      await ref.read(notificationServiceProvider).scheduleExpenseReminders(
            schedule: settings.reminderSchedule,
            messages: reminderMessages,
            titles: reminderTitles,
          );
    } catch (_) {
      // Never let reminder scheduling crash startup.
    }
  }

  void _handleWidgetAction(String action) {
    if (_quickAddOpen) return;
    if (action != 'quick_add' && action != 'quick_add_chai') return;
    // Only makes sense once the user has finished setup (categories exist).
    final ready =
        ref.read(settingsControllerProvider).valueOrNull?.onboardingComplete ??
            false;
    if (!ready) return;
    // The chai preset prefills a familiar tiny expense; the user still confirms.
    final isChai = action == 'quick_add_chai';
    // Defer to ensure the navigator/overlay is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      _quickAddOpen = true;
      QuickAddSheet.show(
        ctx,
        defaultNote: kWidgetQuickAddNote,
        defaultName: isChai ? 'Chai' : null,
        defaultAmount: isChai ? '100' : null,
      ).whenComplete(() => _quickAddOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final settings = settingsAsync.valueOrNull;

    // Keep the global haptics gate in sync with the user's preference. Done in
    // build so it tracks every settings change, including a restore/import.
    if (settings != null) {
      Haptics.enabled = settings.hapticsEnabled;
    }

    final themes = ThemeResolver.resolvePair(
      variant: settings?.themeVariant ?? AppThemeVariant.system,
      accent: settings?.accent ?? AccentPreset.clay,
      font: settings?.fontChoice ?? FontChoice.system,
    );

    // Gate the router on settings loading. We must know `onboardingComplete`
    // *before* the router runs its first redirect, otherwise a brand-new user
    // briefly lands on the dashboard (initialLocation) and only gets bounced to
    // onboarding once settings arrive. Building the router only after settings
    // load means its very first redirect sends new users straight to
    // onboarding. No flash, no tab-tap required.
    if (settings == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    // Once settings are available, arm the daily reminders exactly once.
    if (!_remindersBootstrapped) {
      _remindersBootstrapped = true;
      final snapshot = settings;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _bootstrapDailyReminders(snapshot),
      );
    }

    // Roll every auto-adding recurring payment forward to today, exactly once
    // per launch. This posts any periods that have come due since the last open
    // (so a monthly SIP or rent "recreates" itself each month) and is a no-op
    // when nothing is due. Guarded so a rebuild never double-posts.
    if (!_recurringCaughtUp) {
      _recurringCaughtUp = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await catchUpRecurringPayments(ref);
        } catch (_) {
          // Never let auto-roll crash startup.
        }
      });
    }

    // Reconcile FLAG_SECURE with the user's preference on startup and on every
    // change (secure by default; the native side starts secured in onCreate).
    if (_appliedScreenSecurity != settings.screenSecurityEnabled) {
      _appliedScreenSecurity = settings.screenSecurityEnabled;
      final secure = settings.screenSecurityEnabled;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ScreenSecurityService.setSecure(secure),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BudgetSense',
      debugShowCheckedModeBanner: false,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: themes.mode,
      themeAnimationDuration: settings.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      routerConfig: router,
      builder: (context, child) {
        // Respect the user's reduce-motion preference app-wide.
        final reduce = settings.reduceMotion;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            disableAnimations: reduce || mq.disableAnimations,
            // Honour the system font-size preference (dynamic type) but clamp
            // the extremes so the calm layouts never break.
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.4,
            ),
          ),
          child: WidgetSyncScope(
            child: PaperTexture(
              child: AppLockGate(child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
      },
    );
  }
}
