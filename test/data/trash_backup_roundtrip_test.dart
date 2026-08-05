import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/data/snapshot/app_snapshot_service.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/domain/services/snapshot_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the Trash can and per-expense icons are durable: a backup captures
/// archived (trashed) transactions and their icons, and a restore into a fresh
/// database brings them all back exactly.
void main() {
  for (final format in SnapshotFormat.values) {
    test('trashed items + icons round-trip via ${format.label}', () async {
      final src = AppDatabase.forTesting(NativeDatabase.memory());
      final srcRepo = DriftTransactionRepository(src);
      final now = DateTime(2026, 6, 1, 9);

      TransactionEntity t(String id, {int? icon}) => TransactionEntity(
            id: id,
            type: TransactionType.expense,
            name: 'Txn $id',
            amount: const Money(12345),
            occurredAt: now,
            createdAt: now,
            updatedAt: now,
            iconCodePoint: icon,
          );

      await srcRepo.upsert(t('live', icon: 0xe57f));
      await srcRepo.upsert(t('trashed', icon: 0xe544));
      await srcRepo.archive('trashed'); // -> Trash

      final service = AppSnapshotService(
        src,
        readSettings: () async => const {},
        writeSettings: (_) async {},
      );
      final export = await service.export(format);
      await src.close();

      // Restore into a brand-new empty database.
      final dst = AppDatabase.forTesting(NativeDatabase.memory());
      final dstRepo = DriftTransactionRepository(dst);
      final dstService = AppSnapshotService(
        dst,
        readSettings: () async => const {},
        writeSettings: (_) async {},
      );
      await dstService.importBytes(export.bytes);

      // The live transaction came back with its icon.
      final live = await dstRepo.getById('live');
      expect(live, isNotNull);
      expect(live!.iconCodePoint, 0xe57f);
      expect(live.isArchived, isFalse);

      // The trashed transaction came back INTO the trash, icon intact.
      final trash = await dstRepo.watchArchived().first;
      expect(trash.length, 1);
      expect(trash.single.id, 'trashed');
      expect(trash.single.iconCodePoint, 0xe544);
      expect(trash.single.isArchived, isTrue);

      await dst.close();
    });
  }
}
