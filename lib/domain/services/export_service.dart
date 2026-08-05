import '../../core/constants/enums.dart';
import '../entities/transaction_entity.dart';

/// What slice of data an export covers (Section 15).
enum ExportScope {
  all,
  month,
  range,
  expensesOnly,
  incomeOnly,
  investmentsOnly
}

/// Supported output formats.
enum ExportFormat { csv, xlsx }

/// A resolved category label lookup so exports show human names, not ids.
typedef CategoryNameLookup = String Function(String? categoryId);

/// Abstraction over data export so the CSV and XLSX writers - and any future
/// format - share one contract (Section 17: clear import/export layer). The
/// heavy file-writing lives in the data layer; this defines the shape.
abstract interface class ExportService {
  /// Produces the export as bytes plus a suggested filename. The caller hands
  /// the bytes to the native share sheet (`share_plus`).
  Future<ExportResult> export(
    List<TransactionEntity> transactions, {
    required ExportFormat format,
    required ExportScope scope,
    required CategoryNameLookup categoryName,
    required String currencySymbol,
    String? locale,
  });
}

class ExportResult {
  const ExportResult({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.recordCount,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
  final int recordCount;
}

/// Shared column ordering + row projection so CSV and XLSX stay identical and
/// DRY. Preserves categories, dates, notes, tags, types and currency values
/// (Section 15).
abstract final class ExportSchema {
  static const List<String> headers = [
    'Date',
    'Time',
    'Type',
    'Name',
    'Amount',
    'Category',
    'Merchant',
    'Payment method',
    'Notes',
    'Tags',
  ];

  static List<String> row(
    TransactionEntity t, {
    required CategoryNameLookup categoryName,
    required String currencySymbol,
    String? locale,
  }) {
    final d = t.occurredAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return [
      '${d.year}-${two(d.month)}-${two(d.day)}',
      '${two(d.hour)}:${two(d.minute)}',
      t.type.label,
      t.name,
      t.amount.format(currencySymbol: currencySymbol, locale: locale),
      t.categoryId == null ? '' : categoryName(t.categoryId),
      t.merchant ?? '',
      t.paymentMethodId ?? '',
      t.notes ?? '',
      t.tags.join('; '),
    ];
  }

  /// Filter a transaction list down to the requested [scope].
  static List<TransactionEntity> applyScope(
    List<TransactionEntity> all,
    ExportScope scope,
  ) {
    return switch (scope) {
      ExportScope.all || ExportScope.month || ExportScope.range => all,
      ExportScope.expensesOnly =>
        all.where((t) => t.type == TransactionType.expense).toList(),
      ExportScope.incomeOnly =>
        all.where((t) => t.type == TransactionType.income).toList(),
      ExportScope.investmentsOnly =>
        all.where((t) => t.type == TransactionType.investment).toList(),
    };
  }
}
