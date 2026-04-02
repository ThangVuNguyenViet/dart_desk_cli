import 'dart:convert';

import 'package:dart_desk_cli/src/migration.dart';
import 'package:test/test.dart';

void main() {
  group('Migration DSL', () {
    test('renameField serializes correctly', () {
      final op = renameField('primaryColor', 'mainColor');
      expect(op.toJson(), {'type': 'renameField', 'from': 'primaryColor', 'to': 'mainColor'});
    });

    test('deleteField serializes correctly', () {
      final op = deleteField('legacyFlag');
      expect(op.toJson(), {'type': 'deleteField', 'path': 'legacyFlag'});
    });

    test('setField serializes correctly', () {
      final op = setField('version', 2);
      expect(op.toJson(), {'type': 'setField', 'path': 'version', 'value': 2});
    });

    test('defineMigration creates Migration with correct fields', () {
      final migration = defineMigration(
        title: 'Test migration',
        documentType: 'AppBranding',
        operations: [renameField('old', 'new'), deleteField('remove'), setField('added', true)],
      );
      expect(migration.title, 'Test migration');
      expect(migration.documentType, 'AppBranding');
      expect(migration.operations, hasLength(3));
    });

    test('operationsToJson produces valid JSON array', () {
      final migration = defineMigration(
        title: 'Test',
        documentType: 'Test',
        operations: [renameField('a', 'b'), setField('c', 42)],
      );
      final json = jsonDecode(migration.operationsToJson()) as List;
      expect(json, hasLength(2));
      expect(json[0]['type'], 'renameField');
      expect(json[1]['type'], 'setField');
    });
  });
}
