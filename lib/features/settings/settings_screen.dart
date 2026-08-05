import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/app_info.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/app_log.dart';
import '../common/calm_widgets.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'category_manager_screen.dart';
import 'custom_field_manager_screen.dart';
import 'import/import_hub_screen.dart';
import 'notification_settings_screen.dart';
import 'trash_screen.dart';
import 'profile_screen.dart';
import 'reference_manager_screen.dart';
import 'security_screen.dart';
import 'settings_controller.dart';
import 'settings_state.dart';
import '../../domain/services/snapshot_service.dart';
import 'threshold_editor_screen.dart';
import '../../core/utils/haptics.dart';

/// One searchable setting. Inline controls (theme, currency, ...) carry a
/// [target] key so search scrolls to and highlights them; sub-pages (categories,
/// backup, ...) carry an [open] callback so search navigates straight there.
class _SearchItem {
  const _SearchItem(
    this.label,
    this.section,
    this.keywords, {
    this.target,
    this.open,
  });
  final String label;
  final String section;
  final String keywords;
  final GlobalKey? target;
  final void Function()? open;
}

/// Central configuration hub. Everything is grouped into clean categories, and a
/// search field at the top jumps to (and briefly highlights) any setting by
/// keyword or name. Individual settings still save immediately on interaction.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  String _query = '';
  GlobalKey? _highlighted;

  // One key per category card, so search can scroll to it.
  final _kProfile = GlobalKey();
  final _kAppearance = GlobalKey();
  final _kMoney = GlobalKey();
  final _kManage = GlobalKey();
  final _kData = GlobalKey();
  final _kPrivacy = GlobalKey();
  final _kDanger = GlobalKey();
  final _kAbout = GlobalKey();

  late final List<_SearchItem> _index = [
    _SearchItem(
      'Profile',
      'Profile',
      'profile name nickname age email phone',
      open: () => _push(const ProfileScreen()),
    ),
    _SearchItem(
      'Cloud sync',
      'Data',
      'cloud sync backup drive google restore encrypted',
      open: () => _push(const BackupScreen()),
    ),
    _SearchItem(
      'Theme',
      'Appearance',
      'theme dark light amoled glass system appearance mode',
      target: _kAppearance,
    ),
    _SearchItem(
      'Accent color',
      'Appearance',
      'accent colour color highlight appearance',
      target: _kAppearance,
    ),
    _SearchItem(
      'Typeface and font',
      'Appearance',
      'font typeface handwriting caveat zen maru text',
      target: _kAppearance,
    ),
    _SearchItem(
      'Reduce motion',
      'Appearance',
      'reduce motion animation accessibility calm',
      target: _kAppearance,
    ),
    _SearchItem(
      'Haptic feedback',
      'Appearance',
      'haptic haptics vibration vibrate feedback touch buzz tactile',
      target: _kAppearance,
    ),
    _SearchItem(
      'Currency symbol',
      'Money and display',
      'currency symbol money rupee dollar euro',
      target: _kMoney,
    ),
    _SearchItem(
      'Financial month start',
      'Money and display',
      'financial month start day cycle salary',
      target: _kMoney,
    ),
    _SearchItem(
      'Investment treatment',
      'Money and display',
      'investment savings spending balance treatment',
      target: _kMoney,
    ),
    _SearchItem(
      'Compact numbers',
      'Money and display',
      'compact number format thousand 1.2k display',
      target: _kMoney,
    ),
    _SearchItem(
      'Categories',
      'Manage',
      'category categories color icon bucket manage',
      open: () => _push(const CategoryManagerScreen()),
    ),
    _SearchItem(
      'Accounts',
      'Manage',
      'account accounts cash bank wallet',
      open: () => _push(const AccountsManagerScreen()),
    ),
    _SearchItem(
      'Payment methods',
      'Manage',
      'payment method methods upi card cash',
      open: () => _push(const PaymentMethodsManagerScreen()),
    ),
    _SearchItem(
      'Custom fields',
      'Manage',
      'custom field fields tag mood note',
      open: () => _push(const CustomFieldManagerScreen()),
    ),
    _SearchItem(
      'Thresholds',
      'Manage',
      'threshold thresholds limit budget cap alert',
      open: () => _push(const ThresholdEditorScreen()),
    ),
    _SearchItem(
      'Notifications',
      'Manage',
      'notification notifications reminder alert daily',
      open: () => _push(const NotificationSettingsScreen()),
    ),
    _SearchItem(
      'Export',
      'Data',
      'export csv xlsx excel spreadsheet data',
      open: () => context.push('/export'),
    ),
    _SearchItem(
      'Backup and restore',
      'Data',
      'backup restore snapshot json csv xml import file',
      open: () => _push(const BackupScreen()),
    ),
    _SearchItem(
      'Import from another app',
      'Data',
      'import paisa migrate another app data',
      open: () => _push(const ImportHubScreen()),
    ),
    _SearchItem(
      'Trash',
      'Data',
      'trash bin deleted removed restore recover archive recycle',
      open: () => _push(const TrashScreen()),
    ),
    _SearchItem(
      'Security and app lock',
      'Privacy and security',
      'security lock app lock pin biometric fingerprint face privacy',
      open: () => _push(const SecurityScreen()),
    ),
    _SearchItem(
      'Screen capture protection',
      'Privacy and security',
      'screen capture screenshot recording record protection privacy secure '
          'flag block',
      target: _kPrivacy,
    ),
    _SearchItem(
      'Delete all data',
      'Privacy and security',
      'delete wipe erase reset clear all data danger',
      target: _kDanger,
    ),
    _SearchItem(
      'About and credits',
      'About',
      'about credits author version source github',
      open: () => _push(const AboutScreen()),
    ),
  ];

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _query = '';
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _jumpTo(GlobalKey key) async {
    _clearSearch();
    // The results list is being torn down and the full settings list rebuilt;
    // wait for that layout to settle before measuring the target's position.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final ctx = key.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: Motion.base,
        alignment: 0.08,
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    setState(() => _highlighted = key);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _highlighted = null);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsControllerProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => CalmEmptyState(
            title: 'Settings unavailable',
            message: '$e',
            icon: Icons.error_outline,
          ),
          data: (s) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.sm,
                  Insets.lg,
                  Insets.sm,
                ),
                child: _SearchField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Expanded(
                child: _query.isEmpty
                    ? _buildSettings(context, s, colors)
                    : _buildResults(context, colors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, AppColors colors) {
    final q = _query.toLowerCase();
    final hits = _index
        .where(
          (i) =>
              i.label.toLowerCase().contains(q) ||
              i.keywords.contains(q) ||
              i.section.toLowerCase().contains(q),
        )
        .toList();
    final text = Theme.of(context).textTheme;
    if (hits.isEmpty) {
      return CalmEmptyState(
        title: 'No settings found',
        message: 'Nothing matches "$_query". Try another word.',
        icon: Icons.search_off_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Insets.lg),
      itemCount: hits.length,
      separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
      itemBuilder: (_, i) {
        final item = hits[i];
        return CalmCard(
          onTap: () {
            if (item.open != null) {
              _clearSearch();
              item.open!.call();
            } else if (item.target != null) {
              _jumpTo(item.target!);
            }
          },
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.md,
          ),
          child: Row(
            children: [
              Icon(Icons.tune_outlined, size: 18, color: colors.accent),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label, style: text.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      item.section,
                      style: text.bodySmall?.copyWith(color: colors.textFaint),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, size: 16, color: colors.textFaint),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettings(
      BuildContext context, SettingsState s, AppColors colors) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final text = Theme.of(context).textTheme;

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        _section(
          _kProfile,
          'Profile',
          [
            CalmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: _NavTile(
                icon: Icons.person_outline,
                label: s.userName.isEmpty ? 'Your profile' : s.userName,
                onTap: () => _push(const ProfileScreen()),
                last: true,
              ),
            ),
            const SizedBox(height: Insets.sm),
            CalmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: _NavTile(
                icon: Icons.cloud_outlined,
                label: 'Backup & Sync to Cloud',
                onTap: () => _push(const BackupScreen()),
                last: true,
              ),
            ),
          ],
        ),
        _section(
          _kAppearance,
          'Appearance',
          [
            CalmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: text.titleSmall),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      for (final v in AppThemeVariant.values)
                        ChoiceChip(
                          label: Text(v.label),
                          selected: s.themeVariant == v,
                          onSelected: (_) => controller
                              .save((c) => c.copyWith(themeVariant: v)),
                        ),
                    ],
                  ),
                  const Divider(height: Insets.xl),
                  Text('Accent', style: text.titleSmall),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      for (final a in AccentPreset.values)
                        _AccentDot(
                          preset: a,
                          selected: s.accent == a,
                          onTap: () =>
                              controller.save((c) => c.copyWith(accent: a)),
                        ),
                    ],
                  ),
                  const Divider(height: Insets.xl),
                  Text('Typeface', style: text.titleSmall),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Handwritten styles add character; the system font stays '
                    'crisp for daily use.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: Insets.sm),
                  for (final f in FontChoice.values)
                    _FontOption(
                      choice: f,
                      selected: s.fontChoice == f,
                      last: f == FontChoice.values.last,
                      onTap: () =>
                          controller.save((c) => c.copyWith(fontChoice: f)),
                    ),
                  const Divider(height: Insets.xl),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce motion'),
                    subtitle: const Text('Calmer, near-instant transitions'),
                    value: s.reduceMotion,
                    onChanged: (v) {
                      Haptics.selection();
                      controller.save((c) => c.copyWith(reduceMotion: v));
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Haptic feedback'),
                    subtitle: const Text(
                      'Subtle taps that confirm what you do',
                    ),
                    value: s.hapticsEnabled,
                    onChanged: (v) {
                      // Apply immediately so the confirming tap is felt only when
                      // turning it on, never as a parting buzz when turning off.
                      Haptics.enabled = v;
                      if (v) Haptics.selection();
                      controller.save((c) => c.copyWith(hapticsEnabled: v));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        _section(
          _kMoney,
          'Money and display',
          [
            CalmCard(
              child: Column(
                children: [
                  _Row(
                    label: 'Currency symbol',
                    trailing: Text(s.currencySymbol, style: text.titleSmall),
                    onTap: () => _editCurrency(s.currencySymbol),
                  ),
                  const Divider(height: Insets.lg),
                  _Row(
                    label: 'Financial month starts on day',
                    trailing: Text(
                      '${s.financialMonthStartDay}',
                      style: text.titleSmall,
                    ),
                    onTap: () => _editMonthStart(s.financialMonthStartDay),
                  ),
                  const Divider(height: Insets.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Treat investments as', style: text.bodyMedium),
                      const SizedBox(height: Insets.sm),
                      Wrap(
                        spacing: Insets.sm,
                        children: [
                          for (final t in InvestmentTreatment.values)
                            ChoiceChip(
                              label: Text(t.name),
                              selected: s.investmentTreatment == t,
                              onSelected: (_) => controller.save(
                                (c) => c.copyWith(investmentTreatment: t),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: Insets.lg),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compact number format'),
                    subtitle: const Text('Show large amounts as 1.2K'),
                    value: s.numberFormatCompact,
                    onChanged: (v) => controller
                        .save((c) => c.copyWith(numberFormatCompact: v)),
                  ),
                ],
              ),
            ),
          ],
        ),
        _section(
          _kManage,
          'Manage',
          [
            CalmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Column(
                children: [
                  _NavTile(
                    icon: Icons.category_outlined,
                    label: 'Categories',
                    onTap: () => _push(const CategoryManagerScreen()),
                  ),
                  _NavTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Accounts',
                    onTap: () => _push(const AccountsManagerScreen()),
                  ),
                  _NavTile(
                    icon: Icons.payment_outlined,
                    label: 'Payment methods',
                    onTap: () => _push(const PaymentMethodsManagerScreen()),
                  ),
                  _NavTile(
                    icon: Icons.tune_outlined,
                    label: 'Custom fields',
                    onTap: () => _push(const CustomFieldManagerScreen()),
                  ),
                  _NavTile(
                    icon: Icons.speed_outlined,
                    label: 'Thresholds',
                    onTap: () => _push(const ThresholdEditorScreen()),
                  ),
                  _NavTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () => _push(const NotificationSettingsScreen()),
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        _section(
          _kData,
          'Data',
          [
            CalmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Column(
                children: [
                  _NavTile(
                    icon: Icons.ios_share,
                    label: 'Export',
                    onTap: () => context.push('/export'),
                  ),
                  _NavTile(
                    icon: Icons.backup_outlined,
                    label: 'Backup and restore',
                    onTap: () => _push(const BackupScreen()),
                  ),
                  _NavTile(
                    icon: Icons.swap_horiz,
                    label: 'Import from another app',
                    onTap: () => _push(const ImportHubScreen()),
                  ),
                  _NavTile(
                    icon: Icons.delete_outline,
                    label: 'Trash',
                    onTap: () => _push(const TrashScreen()),
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        _section(
          _kPrivacy,
          'Privacy and security',
          [
            CalmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: _NavTile(
                icon: Icons.lock_outline,
                label: 'Security and app lock',
                onTap: () => _push(const SecurityScreen()),
                last: true,
              ),
            ),
            const SizedBox(height: Insets.sm),
            CalmCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  Icons.screenshot_monitor_outlined,
                  color: colors.textSecondary,
                ),
                title: const Text('Screen capture protection'),
                subtitle: const Text(
                  'Block screenshots and screen recording, and hide the app in '
                  'the recent-apps view. Turn off to capture or record.',
                ),
                value: s.screenSecurityEnabled,
                onChanged: (v) => controller
                    .save((c) => c.copyWith(screenSecurityEnabled: v)),
              ),
            ),
          ],
        ),
        _section(
          _kDanger,
          'Danger zone',
          [
            CalmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: _NavTile(
                icon: Icons.delete_outline,
                label: 'Delete all data',
                danger: true,
                onTap: _confirmWipe,
                last: true,
              ),
            ),
          ],
        ),
        _section(
          _kAbout,
          'About',
          [
            CalmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: _NavTile(
                icon: Icons.info_outline,
                label: 'About and credits',
                onTap: () => _push(const AboutScreen()),
                last: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        Center(
          child: Column(
            children: [
              Text(
                '${AppInfo.appName} · offline-first · v${AppInfo.version}',
                style: text.bodySmall,
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                'Designed & built by ${AppInfo.authorName}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
      ],
    );
  }

  /// A labelled category block that search can scroll to and briefly highlight.
  Widget _section(GlobalKey key, String label, List<Widget> children) {
    final colors = context.colors;
    final on = _highlighted == key;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.all(Insets.xs),
        decoration: BoxDecoration(
          color: on ? colors.accent.withValues(alpha: 0.08) : null,
          borderRadius: Corners.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(label),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _push(Widget screen) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => screen),
      );

  Future<void> _confirmWipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This permanently removes every transaction, category, payment, loan '
          'and setting on this device. Consider a backup first. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Best-effort safety net: grab a full in-memory snapshot before the wipe so
    // we can offer a brief Undo. If the snapshot can't be taken, we still wipe,
    // just without the Undo affordance (forgiving, never blocking).
    final snapshot = ref.read(snapshotServiceProvider);
    List<int>? undoBytes;
    try {
      undoBytes = (await snapshot.export(SnapshotFormat.json)).bytes;
    } catch (e, s) {
      AppLog.error(
        'Pre-wipe snapshot failed; Undo unavailable',
        error: e,
        stackTrace: s,
      );
    }

    await ref.read(databaseProvider).wipeAllData();
    refreshAllDataProviders(ref);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text("Everything's cleared. Fresh start."),
          duration: const Duration(seconds: 8),
          action: undoBytes == null
              ? null
              : SnackBarAction(
                  label: 'Undo', onPressed: () => _undoWipe(undoBytes!)),
        ),
      );
  }

  Future<void> _undoWipe(List<int> bytes) async {
    try {
      await ref.read(snapshotServiceProvider).importBytes(bytes);
      refreshAllDataProviders(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Brought it all back. Nothing lost.')),
        );
    } catch (e, s) {
      AppLog.error('Undo of data wipe failed', error: e, stackTrace: s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't bring it back, sorry.")),
      );
    }
  }

  Future<void> _editCurrency(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Currency symbol'),
        content: TextField(controller: ctrl, maxLength: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref
          .read(settingsControllerProvider.notifier)
          .save((c) => c.copyWith(currencySymbol: result));
    }
  }

  Future<void> _editMonthStart(int current) async {
    final accentColor = context.colors.accent;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Month start day'),
        children: [
          for (var d = 1; d <= 28; d++)
            ListTile(
              title: Text('Day $d'),
              trailing:
                  d == current ? Icon(Icons.check, color: accentColor) : null,
              onTap: () => Navigator.pop(dialogContext, d),
            ),
        ],
      ),
    );
    if (result != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .save((c) => c.copyWith(financialMonthStartDay: result));
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search settings',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: colors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: Corners.md,
          borderSide: BorderSide(color: colors.border, width: Strokes.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.md,
          borderSide: BorderSide(color: colors.border, width: Strokes.hairline),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm, left: Insets.xs),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing, this.onTap});
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _FontOption extends StatelessWidget {
  const _FontOption({
    required this.choice,
    required this.selected,
    required this.onTap,
    this.last = false,
  });

  final FontChoice choice;
  final bool selected;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: Corners.sm,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.md),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? colors.accent : colors.textFaint,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(choice.label, style: text.titleSmall),
                          ),
                          const SizedBox(width: Insets.sm),
                          Flexible(
                            child: Text(
                              choice.description,
                              style: text.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        choice.sample,
                        style: choice.previewStyle(colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!last) Divider(height: 1, color: colors.border),
      ],
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: preset.label,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: preset.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.textPrimary : colors.border,
              width: selected ? 2 : Strokes.hairline,
            ),
          ),
          child: selected
              ? Icon(Icons.check, size: 16, color: colors.onAccent)
              : null,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = danger ? colors.negative : colors.textPrimary;
    return Column(
      children: [
        InkWell(
          onTap: () {
            Haptics.selection();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.md),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: danger ? colors.negative : colors.accent,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: color),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: colors.textFaint),
              ],
            ),
          ),
        ),
        if (!last) Divider(height: 1, color: colors.border),
      ],
    );
  }
}
