import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/export_service.dart';

/// Concrete [ExportService] that serializes transactions to CSV or XLSX.
///
/// Kept in the data layer because it depends on file-format packages; the
/// domain only knows the [ExportService] contract. Both formats reuse
/// [ExportSchema] so columns never drift apart (DRY).
class FileExportService implements ExportService {
  const FileExportService();

  @override
  Future<ExportResult> export(
    List<TransactionEntity> transactions, {
    required ExportFormat format,
    required ExportScope scope,
    required CategoryNameLookup categoryName,
    required String currencySymbol,
    String? locale,
  }) async {
    final scoped = ExportSchema.applyScope(transactions, scope);
    final rows = <List<String>>[
      ExportSchema.headers,
      for (final t in scoped)
        ExportSchema.row(
          t,
          categoryName: categoryName,
          currencySymbol: currencySymbol,
          locale: locale,
        ),
    ];

    final stamp = _stamp();
    return switch (format) {
      ExportFormat.csv => _csv(rows, stamp, scoped.length),
      ExportFormat.xlsx => _xlsx(rows, stamp, scoped.length),
    };
  }

  ExportResult _csv(List<List<String>> rows, String stamp, int count) {
    final content = const ListToCsvConverter().convert(rows);
    return ExportResult(
      bytes: utf8.encode(content),
      fileName: 'budgetsense_$stamp.csv',
      mimeType: 'text/csv',
      recordCount: count,
    );
  }

  ExportResult _xlsx(List<List<String>> rows, String stamp, int count) {
    final book = Excel.createExcel();
    final sheet = book[book.getDefaultSheet() ?? 'Sheet1'];
    for (final row in rows) {
      sheet.appendRow([for (final cell in row) TextCellValue(cell)]);
    }
    final bytes = book.save() ?? <int>[];
    return ExportResult(
      bytes: bytes,
      fileName: 'budgetsense_$stamp.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      recordCount: count,
    );
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
  }
}
