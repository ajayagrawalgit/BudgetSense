import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/domain/entities/config_entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomFieldEntity.decodeList', () {
    test('decodes a JSON string array', () {
      expect(CustomFieldEntity.decodeList('["a","b","c"]'), ['a', 'b', 'c']);
    });

    test('coerces non-string members to strings', () {
      expect(CustomFieldEntity.decodeList('[1,2,3]'), ['1', '2', '3']);
    });

    test('returns an empty list for malformed JSON', () {
      expect(CustomFieldEntity.decodeList('not json'), isEmpty);
    });

    test('returns an empty list when the JSON is not a list', () {
      expect(CustomFieldEntity.decodeList('{"a":1}'), isEmpty);
    });
  });

  group('CustomFieldEntity.decodeTypes', () {
    test('maps valid indices to TransactionType values', () {
      final types = CustomFieldEntity.decodeTypes('["0","1"]');
      expect(types, [TransactionType.expense, TransactionType.income]);
    });

    test('drops out-of-range and non-numeric indices safely', () {
      final types = CustomFieldEntity.decodeTypes('["0","999","x"]');
      expect(types, [TransactionType.expense]);
    });
  });

  test('appliesToType is permissive when appliesTo is empty', () {
    final f = CustomFieldEntity(
      id: 'f',
      name: 'Note',
      fieldType: CustomFieldType.text,
      displayOrder: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(f.appliesToType(TransactionType.expense), isTrue);
    expect(f.appliesToType(TransactionType.income), isTrue);
  });

  test('appliesToType restricts to the configured types', () {
    final f = CustomFieldEntity(
      id: 'f',
      name: 'Note',
      fieldType: CustomFieldType.text,
      displayOrder: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      appliesTo: const [TransactionType.expense],
    );
    expect(f.appliesToType(TransactionType.expense), isTrue);
    expect(f.appliesToType(TransactionType.income), isFalse);
  });

  test('copyWith overrides only the given fields', () {
    final f = CustomFieldEntity(
      id: 'f',
      name: 'Old',
      fieldType: CustomFieldType.text,
      displayOrder: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026, 1, 1),
    );
    final g = f.copyWith(name: 'New', required: true, displayOrder: 3);
    expect(g.id, 'f');
    expect(g.name, 'New');
    expect(g.required, isTrue);
    expect(g.displayOrder, 3);
    // Untouched field is preserved.
    expect(g.fieldType, CustomFieldType.text);
  });
}
