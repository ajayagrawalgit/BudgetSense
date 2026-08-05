import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/loan_repository.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftLoanRepository repo;

  final t0 = DateTime(2026, 1, 1);

  LoanEntity loan(
    String id,
    String name, {
    Money original = const Money(10000000),
    Money outstanding = const Money(6000000),
    Money emi = const Money(500000),
    int interestRateBps = 875,
    DateTime? archivedAt,
  }) =>
      LoanEntity(
        id: id,
        name: name,
        originalPrincipal: original,
        outstandingPrincipal: outstanding,
        emi: emi,
        interestRateBps: interestRateBps,
        frequency: Frequency.monthly,
        startDate: t0,
        createdAt: t0,
        updatedAt: t0,
        archivedAt: archivedAt,
      );

  setUp(() {
    db = newTestDatabase();
    repo = DriftLoanRepository(db);
  });

  tearDown(() => db.close());

  test('upsert then getById round-trips money and rate fields', () async {
    await repo.upsert(loan('l1', 'Home loan'));
    final loaded = await repo.getById('l1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Home loan');
    expect(loaded.originalPrincipal, const Money(10000000));
    expect(loaded.outstandingPrincipal, const Money(6000000));
    expect(loaded.emi, const Money(500000));
    expect(loaded.interestRateBps, 875);
    expect(loaded.interestRatePercent, closeTo(8.75, 1e-9));
  });

  test('repaymentProgress reflects the stored balances', () async {
    await repo.upsert(loan('l1', 'Home loan'));
    final loaded = await repo.getById('l1');
    // 40% of principal repaid (10,000,000 -> 6,000,000 outstanding).
    expect(loaded!.repaymentProgress, closeTo(0.4, 1e-9));
  });

  test('getById returns null for an unknown loan', () async {
    expect(await repo.getById('missing'), isNull);
  });

  test('getAll orders by name and hides archived by default', () async {
    await repo.upsert(loan('b', 'Zebra'));
    await repo.upsert(loan('a', 'Apple'));
    await repo.upsert(loan('c', 'Mango', archivedAt: t0));
    expect((await repo.getAll()).map((l) => l.name), ['Apple', 'Zebra']);
    expect(
      (await repo.getAll(includeArchived: true)).map((l) => l.id).toSet(),
      {'a', 'b', 'c'},
    );
  });

  test('watchAll emits a live list', () async {
    await repo.upsert(loan('l1', 'Home loan'));
    expect((await repo.watchAll().first).single.id, 'l1');
  });

  test('archive hides the loan; delete removes it entirely', () async {
    await repo.upsert(loan('l1', 'Home loan'));
    await repo.archive('l1');
    expect(await repo.getAll(), isEmpty);
    expect((await repo.getById('l1'))!.archivedAt, isNotNull);

    await repo.delete('l1');
    expect(await repo.getById('l1'), isNull);
  });
}
