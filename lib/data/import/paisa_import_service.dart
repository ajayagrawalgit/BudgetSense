import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/category_icons.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/import_service.dart';
import '../database/app_database.dart';
import '../mappers/transaction_mapper.dart';

/// Imports data exported from the **Paisa** budgeting app (and, in future, other
/// apps) into BudgetSense.
///
/// Robustness is the whole point of this feature, so the parser is defensive:
/// every record is handled independently, bad rows are counted and skipped
/// rather than aborting the whole import, foreign icon code points are remapped
/// to BudgetSense's tree-shaken icon set, and all writes happen in a single
/// atomic batch. Paisa UUIDs are reused as BudgetSense ids, which keeps
/// transaction→category/account links intact. Writes are strictly append-only
/// (insert-or-ignore): any id that already exists is left untouched, so
/// re-importing the same file adds nothing and never overwrites or deletes
/// existing data.
class DriftPaisaImportService implements DataImportService {
  DriftPaisaImportService(this._db);

  final AppDatabase _db;

  @override
  Future<ImportPreview> inspect(ImportSource source, List<int> bytes) async {
    _requirePaisa(source);
    final parsed = _parse(bytes);
    return ImportPreview(
      source: source,
      categories: parsed.categories.length,
      accounts: parsed.accounts.length,
      transactions: parsed.transactions.length,
      incomeCount: parsed.incomeCount,
      expenseCount: parsed.expenseCount,
      transferCount: parsed.skippedTransfers,
      earliest: parsed.earliest,
      latest: parsed.latest,
      profile: parsed.profile,
      warnings: parsed.warnings,
    );
  }

  @override
  Future<ImportOutcome> import(
    ImportSource source,
    List<int> bytes, {
    bool importProfile = true,
  }) async {
    _requirePaisa(source);
    final parsed = _parse(bytes);

    // Import is a STRICTLY APPEND-ONLY, safe merge. We never delete and never
    // overwrite: any id that already exists in the database (a local entry the
    // user created, or a row from a previous import) is left completely
    // untouched. Re-importing the same file therefore adds nothing new and
    // changes nothing. This is enforced two ways: `InsertMode.insertOrIgnore`
    // (SQLite skips rows whose primary key already exists) and the pre-count
    // below, which reports exactly how many rows were newly added.
    final existingCats = await _existingIds(
      parsed.categoryIds.toList(),
      (ids) => (_db.select(_db.categories)..where((t) => t.id.isIn(ids)))
          .get()
          .then((rows) => rows.map((r) => r.id)),
    );
    final existingAccts = await _existingIds(
      parsed.accountIds.toList(),
      (ids) => (_db.select(_db.accounts)..where((t) => t.id.isIn(ids)))
          .get()
          .then((rows) => rows.map((r) => r.id)),
    );
    final existingTxns = await _existingIds(
      parsed.transactionIds,
      (ids) => (_db.select(_db.transactions)..where((t) => t.id.isIn(ids)))
          .get()
          .then((rows) => rows.map((r) => r.id)),
    );

    await _db.batch((b) {
      // Reference tables first so transaction FKs resolve within the batch.
      // insertOrIgnore == append only: existing primary keys are never
      // modified or removed.
      b.insertAll(
        _db.categories,
        parsed.categories,
        mode: InsertMode.insertOrIgnore,
      );
      b.insertAll(
        _db.accounts,
        parsed.accounts,
        mode: InsertMode.insertOrIgnore,
      );
      b.insertAll(
        _db.transactions,
        parsed.transactions,
        mode: InsertMode.insertOrIgnore,
      );
    });

    final addedCats = parsed.categories.length - existingCats.length;
    final addedAccts = parsed.accounts.length - existingAccts.length;
    final addedTxns = parsed.transactions.length - existingTxns.length;

    final warnings = [...parsed.warnings];
    final alreadyPresent =
        existingCats.length + existingAccts.length + existingTxns.length;
    if (alreadyPresent > 0) {
      warnings.add(
        '$alreadyPresent records were already in BudgetSense and were left '
        'untouched (import only ever adds, it never overwrites or deletes).',
      );
    }

    return ImportOutcome(
      source: source,
      categories: addedCats,
      accounts: addedAccts,
      transactions: addedTxns,
      skippedTransfers: parsed.skippedTransfers,
      failed: parsed.failed,
      warnings: warnings,
      profile: importProfile ? parsed.profile : null,
    );
  }

  /// Returns the subset of [ids] that already exist, using [query] to fetch
  /// matching ids in chunks (SQLite caps bound variables per statement).
  Future<Set<String>> _existingIds(
    List<String> ids,
    Future<Iterable<String>> Function(List<String> chunk) query,
  ) async {
    final found = <String>{};
    const chunkSize = 500;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
          i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
      if (chunk.isEmpty) continue;
      found.addAll(await query(chunk));
    }
    return found;
  }

  void _requirePaisa(ImportSource source) {
    if (source != ImportSource.paisa) {
      throw const ImportException('This importer only supports Paisa exports.');
    }
  }

  // ---- Parsing -----------------------------------------------------------

  _ParsedPaisa _parse(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const ImportException(
        "That file isn't valid JSON. Make sure you picked the backup file "
        'exported from Paisa.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ImportException(
        "This doesn't look like a Paisa backup (expected a JSON object).",
      );
    }
    final map = decoded;

    // Sanity check: a Paisa backup carries these collections. We accept the
    // file if at least the core ones are present, so minor format drift between
    // Paisa versions doesn't block the import.
    final looksLikePaisa = map.containsKey('transactions') &&
        map.containsKey('categories') &&
        map.containsKey('accounts');
    if (!looksLikePaisa) {
      throw const ImportException(
        "This doesn't look like a Paisa backup. Please export your data from "
        'Paisa (Settings → Backup) and pick that JSON file.',
      );
    }

    final warnings = <String>[];
    final now = DateTime.now();

    // --- Categories (also build a name lookup for income-type heuristics) ---
    final categoryRows = _list(map['categories']);
    final categoryCompanions = <CategoriesCompanion>[];
    final categoryNameById = <String, String>{};
    final categoryIds = <String>{};
    var catSort = 0;
    var catFailed = 0;
    for (final raw in categoryRows) {
      final c = _asMap(raw);
      if (c == null) {
        catFailed++;
        continue;
      }
      final id = _str(c['uuid']);
      if (id == null) {
        catFailed++;
        continue;
      }
      final name = _str(c['name']) ?? 'Imported category';
      categoryNameById[id] = name;
      categoryIds.add(id);
      categoryCompanions.add(
        CategoriesCompanion.insert(
          id: id,
          name: name,
          colorValue: _color(c['color']),
          iconCodePoint: _iconForName(name),
          sortOrder: Value(catSort++),
          semanticBucket: const Value(''),
          isDefault: const Value(false),
          createdAt: _dt(c['createdAt']) ?? now,
          updatedAt: _dt(c['updatedAt']) ?? now,
          syncStatus: const Value(0),
        ),
      );
    }

    // --- Accounts ---
    final accountRows = _list(map['accounts']);
    final accountCompanions = <AccountsCompanion>[];
    final accountIds = <String>{};
    var accSort = 0;
    var accFailed = 0;
    for (final raw in accountRows) {
      final a = _asMap(raw);
      if (a == null) {
        accFailed++;
        continue;
      }
      final id = _str(a['uuid']);
      if (id == null) {
        accFailed++;
        continue;
      }
      accountIds.add(id);
      final name = _str(a['name']);
      final bank = _str(a['bankName']);
      final label = [name, bank]
          .where((s) => s != null && s.isNotEmpty)
          .join(' · ')
          .trim();
      accountCompanions.add(
        AccountsCompanion.insert(
          id: id,
          name: label.isEmpty ? 'Imported account' : label,
          sortOrder: Value(accSort++),
          createdAt: _dt(a['createdAt']) ?? now,
          updatedAt: _dt(a['updatedAt']) ?? now,
          syncStatus: const Value(0),
        ),
      );
    }

    // --- Transactions ---
    final txnRows = _list(map['transactions']);
    final txnCompanions = <TransactionsCompanion>[];
    final txnIds = <String>[];
    var income = 0;
    var expense = 0;
    var skippedTransfers = 0;
    var txnFailed = 0;
    DateTime? earliest;
    DateTime? latest;

    for (final raw in txnRows) {
      final t = _asMap(raw);
      if (t == null) {
        txnFailed++;
        continue;
      }
      try {
        final id = _str(t['uuid']);
        if (id == null) {
          txnFailed++;
          continue;
        }

        final paisaType = _int(t['type']) ?? 0;
        if (paisaType == 2) {
          // Transfer between the user's own accounts: no equivalent in
          // BudgetSense and it must not distort income/expense totals.
          skippedTransfers++;
          continue;
        }

        final occurredAt = _dt(t['createdAt']) ?? _dt(t['updatedAt']) ?? now;
        final updatedAt = _dt(t['updatedAt']) ?? occurredAt;
        // Only keep references that actually resolve to an imported row;
        // foreign keys are enforced, so a dangling id would abort the batch.
        final rawCategoryId = _str(t['category']);
        final categoryId =
            (rawCategoryId != null && categoryIds.contains(rawCategoryId))
                ? rawCategoryId
                : null;
        final rawAccountId = _str(t['account']);
        final accountId =
            (rawAccountId != null && accountIds.contains(rawAccountId))
                ? rawAccountId
                : null;
        final name = _str(t['name']) ??
            (rawCategoryId != null ? categoryNameById[rawCategoryId] : null) ??
            'Imported transaction';

        final isIncome = paisaType == 1;
        if (isIncome) {
          income++;
        } else {
          expense++;
        }

        final entity = TransactionEntity(
          id: id,
          type: isIncome ? TransactionType.income : TransactionType.expense,
          name: name,
          amount: Money.fromMajor(_amount(t['amount'])),
          occurredAt: occurredAt,
          createdAt: _dt(t['createdAt']) ?? occurredAt,
          updatedAt: updatedAt,
          categoryId: categoryId,
          incomeType: isIncome
              ? _incomeTypeFor(
                  name,
                  rawCategoryId != null
                      ? categoryNameById[rawCategoryId]
                      : null,
                )
              : null,
          accountId: accountId,
          notes: _str(t['description']),
          tags: _tags(t['tags']),
          syncStatus: SyncStatus.localOnly,
        );
        txnCompanions.add(TransactionMapper.toCompanion(entity));
        txnIds.add(id);

        earliest = (earliest == null || occurredAt.isBefore(earliest))
            ? occurredAt
            : earliest;
        latest = (latest == null || occurredAt.isAfter(latest))
            ? occurredAt
            : latest;
      } catch (_) {
        txnFailed++;
      }
    }

    final totalFailed = catFailed + accFailed + txnFailed;
    if (catFailed > 0) warnings.add('$catFailed categories could not be read.');
    if (accFailed > 0) warnings.add('$accFailed accounts could not be read.');
    if (txnFailed > 0) {
      warnings
          .add('$txnFailed transactions could not be read and were skipped.');
    }
    if (skippedTransfers > 0) {
      warnings.add(
        '$skippedTransfers transfers between accounts were skipped '
        '(BudgetSense tracks income and expenses, not internal transfers).',
      );
    }

    return _ParsedPaisa(
      categories: categoryCompanions,
      accounts: accountCompanions,
      transactions: txnCompanions,
      categoryIds: categoryIds,
      accountIds: accountIds,
      transactionIds: txnIds,
      incomeCount: income,
      expenseCount: expense,
      skippedTransfers: skippedTransfers,
      failed: totalFailed,
      earliest: earliest,
      latest: latest,
      profile: _profileFrom(map),
      warnings: warnings,
    );
  }

  ImportedProfile? _profileFrom(Map<String, dynamic> map) {
    final users = _list(map['users']);
    if (users.isEmpty) return null;
    // Prefer the selected user, else the first.
    Map<String, dynamic>? chosen;
    for (final raw in users) {
      final u = _asMap(raw);
      if (u == null) continue;
      chosen ??= u;
      if (u['isSelected'] == true) {
        chosen = u;
        break;
      }
    }
    if (chosen == null) return null;
    final name = _str(chosen['name']);
    final code = _str(chosen['currency']);
    if ((name == null || name.isEmpty) && (code == null || code.isEmpty)) {
      return null;
    }
    return ImportedProfile(
      name: name,
      currencyCode: code,
      currencySymbol:
          code == null ? null : _currencySymbols[code.toUpperCase()],
    );
  }

  // ---- Field helpers (all defensive) -------------------------------------

  List<dynamic> _list(Object? v) => v is List ? v : const [];

  Map<String, dynamic>? _asMap(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double _amount(Object? v) {
    final d = switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0,
      _ => 0.0,
    };
    // BudgetSense stores magnitudes; type carries the direction.
    return d.abs();
  }

  DateTime? _dt(Object? v) {
    final s = _str(v);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  List<String> _tags(Object? v) {
    if (v is! List) return const [];
    return v
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Paisa stores colors as ARGB ints, which BudgetSense also uses directly.
  int _color(Object? v) {
    final i = _int(v);
    if (i == null || i == 0) return 0xFF7E97A6; // calm default
    return i;
  }

  IncomeType _incomeTypeFor(String name, String? categoryName) {
    final haystack =
        '${name.toLowerCase()} ${categoryName?.toLowerCase() ?? ''}';
    if (haystack.contains('salary') || haystack.contains('payroll')) {
      return IncomeType.salary;
    }
    if (haystack.contains('bonus')) return IncomeType.bonus;
    if (haystack.contains('interest')) return IncomeType.interest;
    if (haystack.contains('refund')) return IncomeType.refund;
    if (haystack.contains('reimburse')) return IncomeType.reimbursement;
    if (haystack.contains('freelance') || haystack.contains('gig')) {
      return IncomeType.freelance;
    }
    if (haystack.contains('dividend') ||
        haystack.contains('return') ||
        haystack.contains('capital')) {
      return IncomeType.investmentReturns;
    }
    return IncomeType.other;
  }

  /// Foreign icon code points won't exist in BudgetSense's tree-shaken icon
  /// set (they'd render as a blank fallback), so we map by category name to a
  /// sensible built-in icon instead. Returns a code point from [kCategoryIcons]
  /// (or the fallback), keeping icon tree-shaking intact.
  ///
  /// The indices refer to the fixed order of [kCategoryIcons]:
  /// 0 home · 1 star · 2 account_balance · 3 restaurant · 4 directions_car ·
  /// 5 shopping_bag · 6 medical · 7 school · 8 pets · 9 flight · 10 bolt ·
  /// 11 card_giftcard.
  int _iconForName(String name) {
    final n = name.toLowerCase();
    bool has(List<String> keys) => keys.any(n.contains);

    int? index;
    if (has([
      'food',
      'drink',
      'restaurant',
      'grocery',
      'dining',
      'eat',
      'cafe',
      'snack',
    ])) {
      index = 3;
    } else if (has([
      'transport',
      'travel',
      'trip',
      'car',
      'fuel',
      'petrol',
      'cab',
      'taxi',
      'bus',
      'train',
      'uber',
    ])) {
      index = 4;
    } else if (has(['flight', 'airfare', 'airline'])) {
      index = 9;
    } else if (has(['rent', 'home', 'house', 'decor', 'furniture'])) {
      index = 0;
    } else if (has([
      'shop',
      'clothing',
      'footwear',
      'ajio',
      'online',
      'amazon',
      'flipkart',
      'gold',
      'jewel',
      'diamond',
    ])) {
      index = 5;
    } else if (has([
      'health',
      'med',
      'doctor',
      'fitness',
      'gym',
      'hospital',
      'pharmacy',
    ])) {
      index = 6;
    } else if (has(['gift'])) {
      index = 11;
    } else if (has([
      'salary',
      'invest',
      'saving',
      'bank',
      'deposit',
      'income',
    ])) {
      index = 2;
    } else if (has([
      'movie',
      'experience',
      'entertain',
      'fun',
      'game',
      'grooming',
      'beauty',
    ])) {
      index = 1;
    } else if (has([
      'recharge',
      'bill',
      'utility',
      'electric',
      'water',
      'internet',
      'mobile',
      'phone',
    ])) {
      index = 10;
    } else if (has(['school', 'education', 'course', 'tuition', 'book'])) {
      index = 7;
    } else if (has(['pet', 'dog', 'cat'])) {
      index = 8;
    }

    if (index != null && index >= 0 && index < kCategoryIcons.length) {
      return kCategoryIcons[index].codePoint;
    }
    return kFallbackCategoryIcon.codePoint;
  }

  static const Map<String, String> _currencySymbols = {
    'INR': '₹',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'AUD': r'A$',
    'CAD': r'C$',
    'SGD': r'S$',
    'NZD': r'NZ$',
    'AED': 'د.إ',
    'SAR': '﷼',
    'CHF': 'CHF',
    'ZAR': 'R',
    'HKD': r'HK$',
    'THB': '฿',
    'MYR': 'RM',
    'IDR': 'Rp',
    'PHP': '₱',
    'KRW': '₩',
    'RUB': '₽',
    'BRL': r'R$',
    'TRY': '₺',
  };
}

/// Internal container for a fully-parsed Paisa export (companions ready to
/// write, plus counts / metadata for previews and outcomes).
class _ParsedPaisa {
  _ParsedPaisa({
    required this.categories,
    required this.accounts,
    required this.transactions,
    required this.categoryIds,
    required this.accountIds,
    required this.transactionIds,
    required this.incomeCount,
    required this.expenseCount,
    required this.skippedTransfers,
    required this.failed,
    required this.earliest,
    required this.latest,
    required this.profile,
    required this.warnings,
  });

  final List<CategoriesCompanion> categories;
  final List<AccountsCompanion> accounts;
  final List<TransactionsCompanion> transactions;

  /// Ids of the rows in the companion lists above (same order/coverage), used
  /// to detect which are already present so the import stays append-only.
  final Set<String> categoryIds;
  final Set<String> accountIds;
  final List<String> transactionIds;

  final int incomeCount;
  final int expenseCount;
  final int skippedTransfers;
  final int failed;
  final DateTime? earliest;
  final DateTime? latest;
  final ImportedProfile? profile;
  final List<String> warnings;
}
