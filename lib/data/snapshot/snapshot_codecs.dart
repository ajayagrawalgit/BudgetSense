import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:xml/xml.dart';

import '../../domain/services/snapshot_service.dart';
import 'snapshot_tables.dart';

/// Encoders and decoders that turn an [AppSnapshot] into (and back from) JSON,
/// sectioned CSV, or XML - all carrying the identical model with zero loss.
///
/// Value encoding rule shared by CSV and XML: every cell is a `jsonEncode`d
/// scalar, so strings, numbers, booleans, and null are all distinguishable on
/// the way back (`""` empty-string vs `null` vs a real value). JSON keeps values
/// natively. This makes all three formats losslessly round-trippable.
abstract final class SnapshotCodecs {
  // ---- Detection -----------------------------------------------------------

  /// Sniffs [bytes] and returns the snapshot format, or null if unrecognised.
  static SnapshotFormat? detectFormat(List<int> bytes) {
    var head = _leadingText(bytes, 200);
    // Strip a UTF-8 BOM, then leading whitespace.
    if (head.startsWith('﻿')) head = head.substring(1);
    head = head.trimLeft();
    if (head.isEmpty) return null;
    if (head.startsWith('#BUDGETSENSE') || head.startsWith('#SECTION')) {
      return SnapshotFormat.csv;
    }
    if (head.startsWith('<')) return SnapshotFormat.xml;
    if (head.startsWith('{') || head.startsWith('[')) {
      return SnapshotFormat.json;
    }
    return null;
  }

  static String _leadingText(List<int> bytes, int max) {
    final slice = bytes.length <= max ? bytes : bytes.sublist(0, max);
    return utf8.decode(slice, allowMalformed: true);
  }

  // ---- Dispatch ------------------------------------------------------------

  static List<int> encode(AppSnapshot s, SnapshotFormat format) =>
      switch (format) {
        SnapshotFormat.json => _encodeJson(s),
        SnapshotFormat.csv => _encodeCsv(s),
        SnapshotFormat.xml => _encodeXml(s),
      };

  static AppSnapshot decode(List<int> bytes, SnapshotFormat format) =>
      switch (format) {
        SnapshotFormat.json => _decodeJson(bytes),
        SnapshotFormat.csv => _decodeCsv(bytes),
        SnapshotFormat.xml => _decodeXml(bytes),
      };

  // ---- JSON ----------------------------------------------------------------

  static List<int> _encodeJson(AppSnapshot s) {
    final map = <String, Object?>{
      'app': AppSnapshot.appMarker,
      'snapshot': s.version,
      'backupId': _backupId(s),
      'exportedAt': s.exportedAt.toIso8601String(),
      'appVersion': s.appVersion,
      'schemaVersion': s.schemaVersion,
      'settings': s.settings,
      'data': {for (final t in kSnapshotTableOrder) t: s.tables[t] ?? const []},
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(map));
  }

  static AppSnapshot _decodeJson(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const SnapshotException('JSON root is not an object.');
    }
    final map = Map<String, Object?>.from(decoded);
    final settings = _asMap(map['settings']);

    // Prefer the v3 "data" envelope; fall back to top-level table keys so this
    // path also restores legacy DB-only backups (versions 1-2) with no rewrite.
    final dataSource = map['data'] is Map ? _asMap(map['data']) : map;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final t in kSnapshotTableOrder) {
      tables[t] = _asRows(dataSource[t]);
    }
    return AppSnapshot(
      version: (map['snapshot'] as num?)?.toInt() ?? AppSnapshot.currentVersion,
      backupId: _readBackupId(map['backupId'], map),
      exportedAt: DateTime.tryParse('${map['exportedAt']}') ?? DateTime.now(),
      appVersion: '${map['appVersion'] ?? ''}',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 0,
      settings: settings,
      tables: tables,
    );
  }

  // ---- CSV (sectioned) -----------------------------------------------------

  static const _csv = ListToCsvConverter(eol: '\n');

  static List<int> _encodeCsv(AppSnapshot s) {
    final rows = <List<String>>[
      [
        '#BUDGETSENSE',
        '${s.version}',
        s.exportedAt.toIso8601String(),
        s.appVersion,
        '${s.schemaVersion}',
        _backupId(s),
      ],
      ['#SECTION', 'settings'],
      ['key', 'value'],
      for (final e in s.settings.entries) [e.key, jsonEncode(e.value)],
    ];
    for (final table in kSnapshotTableOrder) {
      final data = s.tables[table] ?? const [];
      final header = _tableHeader(table, data);
      rows
        ..add(['#SECTION', table])
        ..add(header);
      for (final row in data) {
        rows.add([
          for (final key in header)
            row.containsKey(key) ? jsonEncode(row[key]) : '',
        ]);
      }
    }
    return utf8.encode(_csv.convert(rows));
  }

  static AppSnapshot _decodeCsv(List<int> bytes) {
    final parsed =
        const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
            .convert(utf8.decode(bytes));
    final settings = <String, Object?>{};
    final tables = <String, List<Map<String, Object?>>>{};
    var version = AppSnapshot.currentVersion;
    var exportedAt = DateTime.now();
    var appVersion = '';
    var schemaVersion = 0;
    var backupId = '';

    var i = 0;
    // Optional marker row.
    if (parsed.isNotEmpty && '${parsed[0].firstOrNull}' == '#BUDGETSENSE') {
      final r = parsed[0];
      version = int.tryParse('${_at(r, 1)}') ?? version;
      exportedAt = DateTime.tryParse('${_at(r, 2)}') ?? exportedAt;
      appVersion = '${_at(r, 3)}';
      schemaVersion = int.tryParse('${_at(r, 4)}') ?? schemaVersion;
      backupId = '${_at(r, 5) ?? ''}';
      i = 1;
    }

    while (i < parsed.length) {
      final row = parsed[i];
      if ('${row.firstOrNull}' != '#SECTION') {
        i++;
        continue;
      }
      final section = '${_at(row, 1)}';
      i++;
      if (section == 'settings') {
        // Skip the ['key','value'] header if present.
        if (i < parsed.length && '${_at(parsed[i], 0)}' == 'key') i++;
        while (i < parsed.length && '${_at(parsed[i], 0)}' != '#SECTION') {
          final kv = parsed[i];
          final key = '${_at(kv, 0)}';
          final cell = '${_at(kv, 1)}';
          if (key.isNotEmpty) {
            settings[key] = cell.isEmpty ? null : jsonDecode(cell);
          }
          i++;
        }
      } else {
        // Table section: next row is the header.
        if (i >= parsed.length) break;
        final header = parsed[i].map((e) => '$e').toList();
        i++;
        final rows = <Map<String, Object?>>[];
        while (i < parsed.length && '${_at(parsed[i], 0)}' != '#SECTION') {
          final cells = parsed[i];
          final map = <String, Object?>{};
          for (var c = 0; c < header.length; c++) {
            final raw = c < cells.length ? '${cells[c]}' : '';
            if (raw.isEmpty) continue; // absent key
            map[header[c]] = jsonDecode(raw);
          }
          rows.add(map);
          i++;
        }
        tables[section] = rows;
      }
    }
    for (final t in kSnapshotTableOrder) {
      tables.putIfAbsent(t, () => const []);
    }
    return AppSnapshot(
      version: version,
      backupId:
          backupId.isNotEmpty ? backupId : _deriveBackupId(exportedAt, tables),
      exportedAt: exportedAt,
      appVersion: appVersion,
      schemaVersion: schemaVersion,
      settings: settings,
      tables: tables,
    );
  }

  // ---- XML ------------------------------------------------------------------

  static List<int> _encodeXml(AppSnapshot s) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8"');
    b.element(
      'budgetsense',
      nest: () {
        b
          ..attribute('app', AppSnapshot.appMarker)
          ..attribute('snapshot', '${s.version}')
          ..attribute('backupId', _backupId(s))
          ..attribute('exportedAt', s.exportedAt.toIso8601String())
          ..attribute('appVersion', s.appVersion)
          ..attribute('schemaVersion', '${s.schemaVersion}');
        b.element(
          'settings',
          nest: () {
            s.settings.forEach((k, v) {
              b.element(
                's',
                nest: () {
                  b.attribute('key', k);
                  _xmlValue(b, v);
                },
              );
            });
          },
        );
        b.element(
          'data',
          nest: () {
            for (final table in kSnapshotTableOrder) {
              final data = s.tables[table] ?? const [];
              b.element(
                'table',
                nest: () {
                  b.attribute('name', table);
                  for (final row in data) {
                    b.element(
                      'row',
                      nest: () {
                        row.forEach((k, v) {
                          b.element(
                            'c',
                            nest: () {
                              b.attribute('key', k);
                              _xmlValue(b, v);
                            },
                          );
                        });
                      },
                    );
                  }
                },
              );
            }
          },
        );
      },
    );
    return utf8
        .encode(b.buildDocument().toXmlString(pretty: true, indent: '  '));
  }

  static void _xmlValue(XmlBuilder b, Object? v) {
    if (v == null) {
      b.attribute('nil', 'true');
    } else {
      b.text(jsonEncode(v));
    }
  }

  static AppSnapshot _decodeXml(List<int> bytes) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(bytes));
    } catch (e) {
      throw SnapshotException('Malformed XML: $e');
    }
    final root = doc.rootElement;
    final settings = <String, Object?>{};
    final sEl = root.getElement('settings');
    if (sEl != null) {
      for (final e in sEl.findElements('s')) {
        final k = e.getAttribute('key');
        if (k == null) continue;
        settings[k] = _xmlRead(e);
      }
    }
    final tables = <String, List<Map<String, Object?>>>{};
    final dEl = root.getElement('data');
    if (dEl != null) {
      for (final t in dEl.findElements('table')) {
        final name = t.getAttribute('name');
        if (name == null) continue;
        final rows = <Map<String, Object?>>[];
        for (final r in t.findElements('row')) {
          final map = <String, Object?>{};
          for (final c in r.findElements('c')) {
            final k = c.getAttribute('key');
            if (k == null) continue;
            map[k] = _xmlRead(c);
          }
          rows.add(map);
        }
        tables[name] = rows;
      }
    }
    for (final t in kSnapshotTableOrder) {
      tables.putIfAbsent(t, () => const []);
    }
    return AppSnapshot(
      version: int.tryParse('${root.getAttribute('snapshot')}') ??
          AppSnapshot.currentVersion,
      backupId: (root.getAttribute('backupId')?.isNotEmpty ?? false)
          ? root.getAttribute('backupId')!
          : _deriveBackupId(
              DateTime.tryParse('${root.getAttribute('exportedAt')}') ??
                  DateTime.now(),
              tables,
            ),
      exportedAt: DateTime.tryParse('${root.getAttribute('exportedAt')}') ??
          DateTime.now(),
      appVersion: root.getAttribute('appVersion') ?? '',
      schemaVersion: int.tryParse('${root.getAttribute('schemaVersion')}') ?? 0,
      settings: settings,
      tables: tables,
    );
  }

  static Object? _xmlRead(XmlElement e) {
    if (e.getAttribute('nil') == 'true') return null;
    final text = e.innerText;
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  // ---- Shared helpers ------------------------------------------------------

  /// The backup id to WRITE: use the snapshot's own if set, else derive a
  /// deterministic one so two encodings of the same snapshot agree.
  static String _backupId(AppSnapshot s) => s.backupId.isNotEmpty
      ? s.backupId
      : _deriveBackupId(s.exportedAt, s.tables);

  /// The backup id to READ from a decoded JSON map, falling back to a derived
  /// id for legacy files that predate the field.
  static String _readBackupId(Object? raw, Map<String, Object?> map) {
    if (raw is String && raw.isNotEmpty) return raw;
    final exportedAt =
        DateTime.tryParse('${map['exportedAt']}') ?? DateTime.now();
    final tables = <String, List<Map<String, Object?>>>{};
    final dataSource = map['data'] is Map ? _asMap(map['data']) : map;
    for (final t in kSnapshotTableOrder) {
      tables[t] = _asRows(dataSource[t]);
    }
    return _deriveBackupId(exportedAt, tables);
  }

  /// Deterministic, non-identifying id for a legacy file: a stable hash of the
  /// export time and per-table row counts. Two decodings of the same file yield
  /// the same id, which keeps re-imports of legacy backups idempotent.
  static String _deriveBackupId(
    DateTime exportedAt,
    Map<String, List<Map<String, Object?>>> tables,
  ) {
    final counts = kSnapshotTableOrder
        .map((t) => '$t:${tables[t]?.length ?? 0}')
        .join(',');
    final basis = '${exportedAt.toUtc().toIso8601String()}|$counts';
    return 'legacy-${basis.hashCode.toUnsigned(32).toRadixString(16)}';
  }

  static List<String> _tableHeader(
    String table,
    List<Map<String, Object?>> rows,
  ) {
    final header =
        (kSnapshotColumns[table] ?? const []).map((c) => c.key).toList();
    final seen = header.toSet();
    for (final row in rows) {
      for (final k in row.keys) {
        if (seen.add(k)) header.add(k); // carry unknown/future columns
      }
    }
    return header;
  }

  static Map<String, Object?> _asMap(Object? v) =>
      v is Map ? Map<String, Object?>.from(v) : <String, Object?>{};

  static List<Map<String, Object?>> _asRows(Object? v) => v is List
      ? v.map((e) => Map<String, Object?>.from(e as Map)).toList()
      : <Map<String, Object?>>[];

  static Object? _at(List<Object?> row, int i) =>
      i < row.length ? row[i] : null;
}
