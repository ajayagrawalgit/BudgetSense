import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/app_info.dart';
import '../../core/constants/branding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../data/seed/default_data.dart';
import '../common/calm_widgets.dart';
import '../settings/settings_controller.dart';

/// A short, skippable first-run experience: welcome -> currency -> financial
/// month start -> offer defaults -> done. Seeds default categories on finish.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 5;

  final _controller = PageController();
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: '₹');
  int _monthStartDay = 1;
  bool _seedDefaults = true;
  final bool _cloudSync = false;
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool applyChoices}) async {
    if (_finishing) return;
    setState(() => _finishing = true);

    try {
      final settings = ref.read(settingsControllerProvider.notifier);

      if (applyChoices) {
        final age = int.tryParse(_ageCtrl.text.trim());
        await settings.save(
          (c) => c.copyWith(
            userName: _nameCtrl.text.trim(),
            userNickname: _nicknameCtrl.text.trim(),
            userAge: age,
            clearAge: age == null,
            userPhone: _phoneCtrl.text.trim(),
            userEmail: _emailCtrl.text.trim(),
            cloudSyncEnabled: _cloudSync,
            currencySymbol: _currencyCtrl.text.trim().isEmpty
                ? '₹'
                : _currencyCtrl.text.trim(),
            financialMonthStartDay: _monthStartDay,
          ),
        );
        if (_seedDefaults) {
          // Opt-in path: seed the starter categories, then seed thresholds -
          // the category-agnostic app-level suggestions PLUS a max-spend rule
          // per starter category, each scoped to that category's real id. The
          // Needs/Wants/Responsibilities thresholds only exist because the user
          // chose the starter categories here; nothing hard-codes their names.
          final created =
              await DefaultDataSeeder(ref.read(databaseProvider)).seedIfEmpty();
          await ref.read(thresholdRepositoryProvider).seedSuggestedIfEmpty(
                extra: starterCategoryThresholds(created),
              );
        }
      } else {
        await DefaultDataSeeder(ref.read(databaseProvider)).seedIfEmpty();
      }

      // Ask for notification permission once, right here at the end of first
      // run, same spot most apps do it. The other Android permissions this
      // app declares (storage, install-packages) are special/contextual ones
      // Android expects to be requested only when the matching feature
      // (local backup, in-app update) is actually used, not upfront.
      try {
        final granted =
            await ref.read(notificationServiceProvider).ensurePermission();
        if (granted) {
          await settings.save((c) => c.copyWith(notificationsEnabled: true));
        }
      } catch (_) {
        // Never let a permission prompt block getting into the app.
      }

      await settings.save((c) => c.copyWith(onboardingComplete: true));
      if (!mounted) return;
      context.go('/dashboard');
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  void _onNext() {
    // The profile page (index 1) gently asks for a name before moving on.
    if (_page == 1 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A first name is all I need to continue.')),
      );
      return;
    }
    if (_page < _pageCount - 1) {
      _controller.nextPage(duration: Motion.base, curve: Curves.easeOut);
    } else {
      _finish(applyChoices: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    _finishing ? null : () => _finish(applyChoices: false),
                child: const Text('Maybe later'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _pageWelcome(text),
                  _pageProfile(text),
                  _pagePreferences(text),
                  _pageCloudSync(text),
                  _pageDefaults(text),
                ],
              ),
            ),
            _DotsAndNext(
              page: _page,
              count: _pageCount,
              finishing: _finishing,
              onNext: _onNext,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(Widget child) => Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: child,
      );

  /// A scrollable padded page for forms so the keyboard never causes overflow.
  Widget _scrollPage(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _pageWelcome(TextTheme text) => _pad(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: 88,
                height: 88,
                child: Image.asset(kBrandMarkAsset),
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text('Hi there 👋', style: text.headlineSmall),
            const SizedBox(height: Insets.sm),
            Text('Welcome to ${AppInfo.appName}', style: text.displaySmall),
            const SizedBox(height: Insets.md),
            Text(
              "I built this as a calm little home for your money, no ads, no "
              "accounts, no snooping. Everything you type stays right here on "
              "your phone.\n\nGive me two minutes and I'll set things up just "
              "the way you like. Nothing here is permanent, you can change all "
              "of it later.",
              style: text.bodyLarge,
            ),
            const SizedBox(height: Insets.xl),
            Text(
              'Designed & built by ${AppInfo.authorName}',
              style: text.bodySmall?.copyWith(color: context.colors.textFaint),
            ),
          ],
        ),
      );

  Widget _pageProfile(TextTheme text) => _scrollPage([
        Text(
          "First things first, what should I call you?",
          style: text.headlineSmall,
        ),
        const SizedBox(height: Insets.md),
        Text(
          "Your first name is all I really need. If you'd rather I use a "
          "nickname, pop it in below and I'll use that everywhere instead. "
          "The rest is totally optional.",
          style: text.bodyMedium,
        ),
        const SizedBox(height: Insets.lg),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'First name'),
        ),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _nicknameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nickname (optional)',
            helperText: "What your friends call you, I'll use this if set",
          ),
        ),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Age (optional)'),
        ),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone (optional)'),
        ),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email (optional)'),
        ),
        const SizedBox(height: Insets.lg),
        CalmCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.favorite_outline,
                size: 18,
                color: context.colors.accent,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  "I get it, handing over your phone and email to yet another "
                  "app feels a bit much. Spam calls and inbox clutter are the "
                  "worst, right? So here's my promise: I won't bug you, not "
                  "once. This stays with you. I only ask so your data can find "
                  "its way back to you if you reinstall, switch phones, or run "
                  "the app somewhere new. Skip it freely, it is entirely your "
                  "call.",
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ]);

  Widget _pagePreferences(TextTheme text) => _scrollPage([
        Text('How you think about money 💰', style: text.headlineSmall),
        const SizedBox(height: Insets.md),
        Text(
          "Which symbol feels like home for your money?",
          style: text.bodyMedium,
        ),
        const SizedBox(height: Insets.lg),
        TextField(
          controller: _currencyCtrl,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'Currency symbol'),
        ),
        const SizedBox(height: Insets.md),
        Text(
          "Payday isn't always the 1st. If your salary lands mid-month, tell "
          "me the day and I'll count your month from there. Not sure? Leaving "
          "it at day 1 is perfectly fine.",
          style: text.bodyMedium,
        ),
        const SizedBox(height: Insets.md),
        CalmCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Financial month starts on day', style: text.bodyMedium),
              DropdownButton<int>(
                value: _monthStartDay,
                underline: const SizedBox.shrink(),
                items: [
                  for (var d = 1; d <= 28; d++)
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => setState(() => _monthStartDay = v ?? 1),
              ),
            ],
          ),
        ),
      ]);

  Widget _pageCloudSync(TextTheme text) => _scrollPage([
        Text('Cloud backup', style: text.headlineSmall),
        const SizedBox(height: Insets.md),
        Text(
          'Your data lives safely on this device. If you ever want an '
          'off-device copy, BudgetSense can keep one encrypted backup in your '
          'own Google Drive, protected by a passphrase only you know.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: Insets.md),
        Text(
          'It is completely optional and stays off until you choose it. You can '
          'turn it on any time in Settings, under Backup & restore.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: Insets.lg),
        CalmCard(
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: context.colors.accent),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'Everything is encrypted on this device before it ever leaves '
                  'your phone.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ]);

  Widget _pageDefaults(TextTheme text) => _pad(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('One last thing 🌱', style: text.headlineSmall),
            const SizedBox(height: Insets.md),
            Text(
              "A blank app can feel a bit lonely, so I can drop in a few "
              "starter categories and some "
              "gentle spending thresholds to get you going. Rename, tweak or "
              "delete any of them whenever you like, they're just a head start.",
              style: text.bodyMedium,
            ),
            const SizedBox(height: Insets.lg),
            CalmCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add starter categories & thresholds'),
                value: _seedDefaults,
                onChanged: (v) => setState(() => _seedDefaults = v),
              ),
            ),
          ],
        ),
      );
}

class _DotsAndNext extends StatelessWidget {
  const _DotsAndNext({
    required this.page,
    required this.count,
    required this.finishing,
    required this.onNext,
  });

  final int page;
  final int count;
  final bool finishing;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLast = page == count - 1;
    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.only(right: Insets.xs),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == page ? colors.accent : colors.border,
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: finishing ? null : onNext,
            child: Text(isLast ? 'Get started' : 'Next'),
          ),
        ],
      ),
    );
  }
}
