import 'dart:convert';

/// Defines a migration with a title, target document type, and operations.
class Migration {
  final String title;
  final String documentType;
  final List<MigrationOp> operations;

  Migration({
    required this.title,
    required this.documentType,
    required this.operations,
  });

  /// Serialize operations to JSON string for sending to the backend.
  String operationsToJson() {
    return jsonEncode(operations.map((op) => op.toJson()).toList());
  }
}

/// A single migration operation.
sealed class MigrationOp {
  Map<String, dynamic> toJson();
}

class _RenameField extends MigrationOp {
  final String from;
  final String to;
  _RenameField(this.from, this.to);

  @override
  Map<String, dynamic> toJson() => {'type': 'renameField', 'from': from, 'to': to};
}

class _DeleteField extends MigrationOp {
  final String path;
  _DeleteField(this.path);

  @override
  Map<String, dynamic> toJson() => {'type': 'deleteField', 'path': path};
}

class _SetField extends MigrationOp {
  final String path;
  final dynamic value;
  _SetField(this.path, this.value);

  @override
  Map<String, dynamic> toJson() => {'type': 'setField', 'path': path, 'value': value};
}

/// Create a migration definition.
Migration defineMigration({
  required String title,
  required String documentType,
  required List<MigrationOp> operations,
}) {
  return Migration(title: title, documentType: documentType, operations: operations);
}

/// Rename a field (supports dot-notation for nested paths).
MigrationOp renameField(String from, String to) => _RenameField(from, to);

/// Delete a field and all its sub-keys.
MigrationOp deleteField(String path) => _DeleteField(path);

/// Set a field to a static value.
MigrationOp setField(String path, dynamic value) => _SetField(path, value);
