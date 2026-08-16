import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/export/export_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/insights/month_close_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/payments/payments_screen.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/settings_state.dart';
import '../features/shell/app_shell.dart';

/// Navigator keys for each bottom-nav branch. Exposed so the shell can pop a
/// branch back to its root when its tab is tapped while already selected.
final branchNavigatorKeys = <GlobalKey<NavigatorState>>[
  GlobalKey<NavigatorState>(debugLabel: 'dashboardNav'),
  GlobalKey<NavigatorState>(debugLabel: 'expensesNav'),
  GlobalKey<NavigatorState>(debugLabel: 'paymentsNav'),
  GlobalKey<NavigatorState>(debugLabel: 'insightsNav'),
  GlobalKey<NavigatorState>(debugLabel: 'settingsNav'),
];

/// Root navigator key. Exposed so out-of-tree triggers (e.g. a home-screen
/// widget launching the quick-add flow) can present UI over the app.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// go_router configuration. Redirects into onboarding until the user has
/// completed (or skipped) first-run setup (Section 23).
final routerProvider = Provider<GoRouter>((ref) {
  final rootKey = rootNavigatorKey;

  // Re-run the onboarding redirect whenever settings change. Without this the
  // redirect only fires on navigation, so on a fresh install the dashboard
  // would show first and onboarding only appear after tapping another tab.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen<AsyncValue<SettingsState>>(
    settingsControllerProvider,
    (_, __) => refresh.value++,
  );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      if (settings == null) return null; // still loading; stay put
      final onboarding = !settings.onboardingComplete;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (onboarding && !atOnboarding) return '/onboarding';
      if (!onboarding && atOnboarding) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/month-close',
        builder: (context, state) => const MonthCloseScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => AppShell(navShell: navShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[0],
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[1],
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (context, state) => const ExpensesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[2],
            routes: [
              GoRoute(
                path: '/payments',
                builder: (context, state) => const PaymentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[3],
            routes: [
              GoRoute(
                path: '/insights',
                builder: (context, state) => const InsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[4],
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
