import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/reminder_messages.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/reminder_schedule.dart';
import '../common/calm_widgets.dart';
import 'settings_controller.dart';
import 'settings_state.dart';

/// Notification preferences (Sections 12 & 18). Permission is requested only
/// when the user turns notifications on, with a clear explanation. The record
/// reminder is fully configurable: daily, weekly, or monthly, at a chosen time.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            CalmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BudgetSense uses on-device reminders only. Nothing leaves '
                    'your phone. We ask for permission just once, here.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: Insets.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable notifications'),
                    value: settings.notificationsEnabled,
                    onChanged: (v) async {
                      Haptics.selection();
                      final service = ref.read(notificationServiceProvider);
                      if (v) {
                        final granted = await service.ensurePermission();
                        if (!granted) return;
                        if (settings.dailyRecordRemindersEnabled) {
                          await service.scheduleExpenseReminders(
                            schedule: settings.reminderSchedule,
                            messages: reminderMessages,
                            titles: reminderTitles,
                          );
                        }
                      } else {
                        await service.cancelAll();
                      }
                      await controller
                          .save((c) => c.copyWith(notificationsEnabled: v));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            if (settings.notificationsEnabled) ...[
              CalmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remind me to record expenses'),
                      subtitle: Text(
                        settings.dailyRecordRemindersEnabled
                            ? settings.reminderSchedule.describe()
                            : 'A gentle nudge so spending never goes untracked',
                      ),
                      value: settings.dailyRecordRemindersEnabled,
                      onChanged: (v) async {
                        Haptics.selection();
                        await controller.save(
                          (c) => c.copyWith(dailyRecordRemindersEnabled: v),
                        );
                        await _reschedule(ref);
                      },
                    ),
                    if (settings.dailyRecordRemindersEnabled)
                      _ScheduleEditor(
                        settings: settings,
                        onChanged: (transform) async {
                          await controller.save(transform);
                          await _reschedule(ref);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              CalmCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Payment & EMI reminders'),
                      value: settings.paymentRemindersEnabled,
                      onChanged: (v) {
                        Haptics.selection();
                        controller.save(
                          (c) => c.copyWith(paymentRemindersEnabled: v),
                        );
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Threshold alerts'),
                      value: settings.thresholdAlertsEnabled,
                      onChanged: (v) {
                        Haptics.selection();
                        controller.save(
                          (c) => c.copyWith(thresholdAlertsEnabled: v),
                        );
                      },
                    ),
                    const Divider(height: Insets.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _sendTest(context, ref),
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                              size: 16,
                            ),
                            label: const Text('Send a test'),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _rescheduleAll(context, ref),
                            icon: const Icon(
                              Icons.event_available_outlined,
                              size: 16,
                            ),
                            label: const Text('Reschedule'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Reminders are inexact by design, so Android can batch them and '
                'save battery. They may arrive a few minutes around the set time.',
                style: text.bodySmall?.copyWith(color: colors.textFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Re-lays the expense nudges from the freshly-saved settings (or clears them
  /// if the reminder was switched off).
  Future<void> _reschedule(WidgetRef ref) async {
    final service = ref.read(notificationServiceProvider);
    final settings = ref.read(settingsControllerProvider).valueOrNull;
    if (settings == null) return;
    if (settings.notificationsEnabled && settings.dailyRecordRemindersEnabled) {
      await service.scheduleExpenseReminders(
        schedule: settings.reminderSchedule,
        messages: reminderMessages,
        titles: reminderTitles,
      );
    } else {
      await service.cancelExpenseReminders();
    }
  }

  Future<void> _sendTest(BuildContext context, WidgetRef ref) async {
    Haptics.confirm();
    final service = ref.read(notificationServiceProvider);
    final granted = await service.ensurePermission();
    if (!granted) return;
    final rand = Random();
    final title = reminderTitles[rand.nextInt(reminderTitles.length)];
    final body = reminderMessages[rand.nextInt(reminderMessages.length)];
    await service.showNow(910001, title, body);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sent a sample reminder your way')),
    );
  }

  Future<void> _rescheduleAll(BuildContext context, WidgetRef ref) async {
    Haptics.confirm();
    final service = ref.read(notificationServiceProvider);
    final planner = ref.read(reminderPlannerProvider);
    final now = DateTime.now();
    final payments =
        ref.read(recurringPaymentsStreamProvider).valueOrNull ?? const [];
    final loans = ref.read(loansStreamProvider).valueOrNull ?? const [];
    final settings = ref.read(settingsControllerProvider).valueOrNull;

    await service.cancelAll();
    final alerts = [
      ...planner.planForPayments(payments, now: now),
      ...planner.planForLoans(loans, now: now),
    ];
    for (final a in alerts) {
      await service.schedule(a);
    }
    if (settings?.dailyRecordRemindersEnabled ?? true) {
      await service.scheduleExpenseReminders(
        schedule: settings?.reminderSchedule ?? const ReminderSchedule(),
        messages: reminderMessages,
        titles: reminderTitles,
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scheduled ${alerts.length} payment reminders plus your nudges',
        ),
      ),
    );
  }
}

/// The frequency + time + day editor shown when the record reminder is on.
class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor({required this.settings, required this.onChanged});

  final SettingsState settings;
  final Future<void> Function(SettingsState Function(SettingsState)) onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs, bottom: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How often', style: text.labelMedium),
          const SizedBox(height: Insets.xs),
          Wrap(
            spacing: Insets.sm,
            children: [
              for (final f in ReminderFrequency.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: settings.reminderFrequency == f,
                  onSelected: (_) {
                    Haptics.selection();
                    onChanged((c) => c.copyWith(reminderFrequency: f));
                  },
                ),
            ],
          ),
          if (settings.reminderFrequency == ReminderFrequency.weekly) ...[
            const SizedBox(height: Insets.md),
            Text('On which day', style: text.labelMedium),
            const SizedBox(height: Insets.xs),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: [
                for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                  ChoiceChip(
                    label: Text(_shortWeekday(d)),
                    selected: settings.reminderWeekday == d,
                    onSelected: (_) {
                      Haptics.selection();
                      onChanged((c) => c.copyWith(reminderWeekday: d));
                    },
                  ),
              ],
            ),
          ],
          if (settings.reminderFrequency == ReminderFrequency.monthly) ...[
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Expanded(
                    child: Text('On day of month', style: text.labelMedium)),
                DropdownButton<int>(
                  value: settings.reminderDayOfMonth.clamp(1, 28),
                  onChanged: (v) {
                    if (v == null) return;
                    Haptics.selection();
                    onChanged((c) => c.copyWith(reminderDayOfMonth: v));
                  },
                  items: [
                    for (var d = 1; d <= 28; d++)
                      DropdownMenuItem(value: d, child: Text('$d')),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: Insets.md),
          InkWell(
            borderRadius: Corners.sm,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: settings.reminderHour,
                  minute: settings.reminderMinute,
                ),
                helpText: 'When should the reminder arrive?',
              );
              if (picked == null) return;
              Haptics.selection();
              await onChanged(
                (c) => c.copyWith(
                  reminderHour: picked.hour,
                  reminderMinute: picked.minute,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: colors.textFaint),
                  const SizedBox(width: Insets.sm),
                  Expanded(child: Text('Time', style: text.bodyMedium)),
                  Text(
                    _formatTime(settings.reminderHour, settings.reminderMinute),
                    style: text.titleSmall,
                  ),
                  const SizedBox(width: Insets.xs),
                  Icon(Icons.edit_outlined, size: 15, color: colors.textFaint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortWeekday(int d) => switch (d) {
        DateTime.monday => 'Mon',
        DateTime.tuesday => 'Tue',
        DateTime.wednesday => 'Wed',
        DateTime.thursday => 'Thu',
        DateTime.friday => 'Fri',
        DateTime.saturday => 'Sat',
        DateTime.sunday => 'Sun',
        _ => 'Mon',
      };

  static String _formatTime(int h, int m) {
    final period = h < 12 ? 'AM' : 'PM';
    var hour12 = h % 12;
    if (hour12 == 0) hour12 = 12;
    return '$hour12:${m.toString().padLeft(2, '0')} $period';
  }
}
