import '../../core/services/notification_service.dart';
import '../../core/utils/friendly_date.dart';
import '../entities/commitment_entities.dart';

/// Pure planner that turns recurring payments & loans into concrete
/// [ScheduledAlert]s (Section 12). No plugin, no I/O - unit-testable. The
/// caller feeds the results to a [NotificationService].
class ReminderPlanner {
  const ReminderPlanner();

  /// Build reminder alerts for the given [payments], honoring each payment's
  /// reminder settings and skipping archived/disabled ones.
  List<ScheduledAlert> planForPayments(
    List<RecurringPaymentEntity> payments, {
    required DateTime now,
  }) {
    final alerts = <ScheduledAlert>[];
    for (final p in payments) {
      if (p.isArchived || !p.reminderEnabled) continue;
      final remindAt = p.nextDueDate.subtract(
        Duration(days: p.reminderDaysBefore),
      );
      if (remindAt.isBefore(now.subtract(const Duration(days: 1)))) continue;
      alerts.add(
        ScheduledAlert(
          id: _stableId(p.id),
          title: 'Payment due soon',
          body: '${p.name} is due on ${FriendlyDate.short(p.nextDueDate)}.',
          when: remindAt,
        ),
      );
    }
    return alerts;
  }

  /// Build reminder alerts for loan EMIs.
  List<ScheduledAlert> planForLoans(
    List<LoanEntity> loans, {
    required DateTime now,
  }) {
    final alerts = <ScheduledAlert>[];
    for (final l in loans) {
      if (l.isArchived || l.nextPaymentDate == null) continue;
      final remindAt = l.nextPaymentDate!.subtract(const Duration(days: 1));
      if (remindAt.isBefore(now.subtract(const Duration(days: 1)))) continue;
      alerts.add(
        ScheduledAlert(
          id: _stableId('loan_${l.id}'),
          title: 'EMI due soon',
          body:
              '${l.name} EMI is due on ${FriendlyDate.short(l.nextPaymentDate!)}.',
          when: remindAt,
        ),
      );
    }
    return alerts;
  }

  /// A deterministic small positive int id derived from a uuid string, so
  /// rescheduling a payment replaces its previous notification.
  int _stableId(String key) => key.hashCode & 0x7fffffff;
}
