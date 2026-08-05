import 'package:budgetsense/core/utils/financial_calendar.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the "no restart needed after import" fix at the data-stream level.
///
/// It reproduces the exact failure mode the user hit: a bulk write that lands in
/// the database but bypasses Drift's per-write stream notifications (simulated
/// with a raw customStatement, standing in for the transaction-wrapped snapshot
/// restore). The stream that was already being watched stays stale, but a fresh
/// stream, which is exactly what `refreshAllDataProviders` creates by
/// invalidating the providers, immediately sees the new row. No app restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cal = FinancialCalendar(monthStartDay: 1);

  test('a fresh watch (what invalidation creates) sees a stealth insert',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftTransactionRepository(db);

    final now = DateTime.now();
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 't1',
            type: 0,
            name: 'Coffee',
            amountMinor: 5000,
            occurredAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Subscribe a long-lived stream, mirroring a screen kept alive off-stage in
    // the shell's IndexedStack while the user is on the Backup screen.
    final seen = <int>[];
    final sub = repo
        .watchForMonth(now, calendar: cal)
        .listen((rows) => seen.add(rows.length));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.last, 1, reason: 'seeded row is visible on the live stream');

    // Reuse t1's raw stored timestamps so the stealth row uses Drift's exact
    // on-disk DateTime format (int seconds or ISO text, whichever it is).
    final raw = await db.customSelect(
      'SELECT occurred_at, created_at, updated_at FROM transactions '
      'WHERE id = ?',
      variables: [const Variable<String>('t1')],
    ).getSingle();

    // Stealth write: a raw INSERT that Drift's stream tracking does NOT observe.
    await db.customStatement(
      'INSERT INTO transactions '
      '(id, created_at, updated_at, sync_status, type, name, amount_minor, '
      'occurred_at, tags_json) '
      "VALUES ('t2', ?, ?, 0, 0, 'Tea', 3000, ?, '[]')",
      <Object?>[
        raw.data['created_at'],
        raw.data['updated_at'],
        raw.data['occurred_at'],
      ],
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // The already-open stream stayed stale: this is exactly the bug: the UI did
    // not update, so a restart appeared to be required.
    expect(seen.last, 1,
        reason: 'live stream misses the untracked write (bug)');

    // The fix: invalidating the provider disposes the old subscription (done
    // here by cancelling it), so Drift releases its cached stream. Riverpod then
    // builds a NEW stream on next read, which re-queries and sees both rows.
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final fresh = await repo.watchForMonth(now, calendar: cal).first;
    expect(fresh.length, 2, reason: 'a fresh watch surfaces the new row');

    // Sanity: a one-shot (never-cached) read agrees the data is really there.
    final range = cal.monthRangeFor(now);
    final oneShot = await repo.getInRange(range);
    expect(oneShot.where((t) => t.archivedAt == null).length, 2);
  });
}
