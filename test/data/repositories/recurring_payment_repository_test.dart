import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/recurring_payment_repository.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftRecurringPaymentRepository repo;

  final t0 = DateTime(2026, 1, 1);

  RecurringPaymentEntity payment(
    String id,
    String name, {
    required DateTime nextDue,
    PaymentKind kind = PaymentKind.subscription,
    Money amount = const Money(29900),
    bool autoAdd = false,
    DateTime? archivedAt,
  }) =>
      RecurringPaymentEntity(
        id: id,
        name: name,
        amount: amount,
        kind: kind,
        frequency: Frequency.monthly,
        startDate: t0,
        nextDueDate: nextDue,
        createdAt: t0,
        updatedAt: t0,
        autoAddTransaction: autoAdd,
        archivedAt: archivedAt,
      );

  setUp(() {
    db = newTestDatabase();
    repo = DriftRecurringPaymentRepository(db);
  });

  tearDown(() => db.close());

  test('upsert then getById round-trips all fields', () async {
    await repo.upsert(
      payment(
        'p1',
        'Netflix',
        nextDue: DateTime(2026, 2, 1),
        kind: PaymentKind.sip,
        amount: const Money(500000),
        autoAdd: true,
      ),
    );
    final loaded = await repo.getById('p1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Netflix');
    expect(loaded.amount, const Money(500000));
    expect(loaded.kind, PaymentKind.sip);
    expect(loaded.isInvestment, isTrue);
    expect(loaded.autoAddTransaction, isTrue);
    expect(loaded.nextDueDate, DateTime(2026, 2, 1));
  });

  test('getById returns null for an unknown payment', () async {
    expect(await repo.getById('none'), isNull);
  });

  test('getAll orders by nextDueDate ascending', () async {
    await repo.upsert(payment('late', 'Late', nextDue: DateTime(2026, 3, 1)));
    await repo.upsert(payment('soon', 'Soon', nextDue: DateTime(2026, 1, 15)));
    await repo.upsert(payment('mid', 'Mid', nextDue: DateTime(2026, 2, 10)));
    expect((await repo.getAll()).map((p) => p.id), ['soon', 'mid', 'late']);
  });

  test('archived payments are hidden unless included', () async {
    await repo.upsert(payment('live', 'Live', nextDue: DateTime(2026, 2, 1)));
    await repo.upsert(
      payment('old', 'Old', nextDue: DateTime(2026, 2, 1), archivedAt: t0),
    );
    expect((await repo.getAll()).map((p) => p.id), ['live']);
    expect(
      (await repo.getAll(includeArchived: true)).map((p) => p.id).toSet(),
      {'live', 'old'},
    );
  });

  test('watchAll emits a live ordered list', () async {
    await repo.upsert(payment('a', 'A', nextDue: DateTime(2026, 2, 5)));
    await repo.upsert(payment('b', 'B', nextDue: DateTime(2026, 2, 1)));
    expect((await repo.watchAll().first).map((p) => p.id), ['b', 'a']);
  });

  test('archive hides then delete removes the payment', () async {
    await repo.upsert(payment('p1', 'Rent', nextDue: DateTime(2026, 2, 1)));
    await repo.archive('p1');
    expect(await repo.getAll(), isEmpty);
    await repo.delete('p1');
    expect(await repo.getById('p1'), isNull);
  });

  test('isOverdue and isUpcomingWithin use date-only boundaries', () async {
    final now = DateTime(2026, 2, 10, 14);
    final overdue = payment('o', 'O', nextDue: DateTime(2026, 2, 9));
    final today = payment('t', 'T', nextDue: DateTime(2026, 2, 10));
    final soon = payment('s', 'S', nextDue: DateTime(2026, 2, 13));
    final far = payment('f', 'F', nextDue: DateTime(2026, 3, 1));
    expect(overdue.isOverdue(now), isTrue);
    expect(today.isOverdue(now), isFalse);
    expect(soon.isUpcomingWithin(now, 7), isTrue);
    expect(far.isUpcomingWithin(now, 7), isFalse);
  });
}
