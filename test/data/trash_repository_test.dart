import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/financial_calendar.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Trash can behaviour: swipe-delete soft-deletes (archives) rather than
/// destroying, archived items are hidden from the month view but visible in the
/// trash stream, restore brings them back, and empty-trash permanently clears.
void main() {
  late AppDatabase db;
  late DriftTransactionRepository repo;
  const calendar = FinancialCalendar(monthStartDay: 1);

  TransactionEntity txn(String id, DateTime when, {int? icon}) =>
      TransactionEntity(
        id: id,
        type: TransactionType.expense,
        name: 'Txn $id',
        amount: const Money(10000),
        occurredAt: when,
        createdAt: when,
        updatedAt: when,
        iconCodePoint: icon,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTransactionRepository(db);
  });

  tearDown(() => db.close());

  test('archive moves a transaction to Trash and out of the month view',
      () async {
    final now = DateTime.now();
    await repo.upsert(txn('a', now));

    expect((await repo.watchForMonth(now, calendar: calendar).first).length, 1);
    expect(await repo.watchArchived().first, isEmpty);

    await repo.archive('a');

    expect(await repo.watchForMonth(now, calendar: calendar).first, isEmpty);
    final trash = await repo.watchArchived().first;
    expect(trash.length, 1);
    expect(trash.single.id, 'a');
    expect(trash.single.isArchived, isTrue);
  });

  test('unarchive restores a trashed transaction', () async {
    final now = DateTime.now();
    await repo.upsert(txn('a', now));
    await repo.archive('a');
    await repo.unarchive('a');

    expect(await repo.watchArchived().first, isEmpty);
    expect((await repo.watchForMonth(now, calendar: calendar).first).length, 1);
  });

  test('emptyTrash permanently deletes only archived rows', () async {
    final now = DateTime.now();
    await repo.upsert(txn('keep', now));
    await repo.upsert(txn('trash1', now));
    await repo.upsert(txn('trash2', now));
    await repo.archive('trash1');
    await repo.archive('trash2');

    await repo.emptyTrash();

    expect(await repo.watchArchived().first, isEmpty);
    // The live (non-archived) transaction is untouched.
    final live = await repo.watchForMonth(now, calendar: calendar).first;
    expect(live.map((t) => t.id), ['keep']);
    // And it's truly gone, not just archived.
    expect(await repo.getById('trash1'), isNull);
  });

  test('latestActiveDate ignores archived rows', () async {
    final jan = DateTime(2026, 1, 15);
    final jun = DateTime(2026, 6, 20);
    await repo.upsert(txn('old', jan));
    await repo.upsert(txn('new', jun));

    expect(await repo.latestActiveDate(), jun);

    // Archiving the newest should make January the latest active date.
    await repo.archive('new');
    expect(await repo.latestActiveDate(), jan);
  });

  test('per-transaction iconCodePoint round-trips through the DB', () async {
    final now = DateTime.now();
    await repo.upsert(txn('a', now, icon: 0xe57f));
    final loaded = await repo.getById('a');
    expect(loaded!.iconCodePoint, 0xe57f);
  });
}
