import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../config.dart';
import '../credentials.dart';
import '../migration.dart';

class MigrationCommand extends Command {
  @override
  String get name => 'migration';

  @override
  String get description => 'Manage schema migrations';

  MigrationCommand() {
    addSubcommand(_CreateSubcommand());
    addSubcommand(_ListSubcommand());
    addSubcommand(_RunSubcommand());
  }
}

// ---------------------------------------------------------------------------
// create
// ---------------------------------------------------------------------------

class _CreateSubcommand extends Command {
  @override
  String get name => 'create';

  @override
  String get description => 'Create a new migration file';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      stderr.writeln('Usage: dartdesk migration create <title>');
      exit(64);
    }

    final title = rest.join(' ');
    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final now = DateTime.now();
    final datePart =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileName = '${datePart}_$slug.dart';

    final migrationsDir = Directory(
        p.join(Directory.current.path, 'migrations'));
    if (!migrationsDir.existsSync()) {
      migrationsDir.createSync(recursive: true);
      stdout.writeln('Created migrations/ directory.');
    }

    final file = File(p.join(migrationsDir.path, fileName));
    file.writeAsStringSync(_migrationTemplate(title));

    stdout.writeln('Created migration: migrations/$fileName');
  }

  String _migrationTemplate(String title) {
    return '''import 'package:dart_desk_cli/migration.dart';

final migration = defineMigration(
  title: '$title',
  documentType: 'TODO: set document type',
  operations: [
    // renameField('oldName', 'newName'),
    // deleteField('fieldToRemove'),
    // setField('fieldName', 'value'),
  ],
);
''';
  }
}

// ---------------------------------------------------------------------------
// list
// ---------------------------------------------------------------------------

class _ListSubcommand extends Command {
  @override
  String get name => 'list';

  @override
  String get description => 'List local migrations and their applied status';

  _ListSubcommand() {
    argParser.addOption('token', help: 'API token for CI/CD');
  }

  @override
  Future<void> run() async {
    final config = CmsConfig.load();
    final token = _resolveToken(argResults);

    // Collect local migration files.
    final migrationsDir = Directory(
        p.join(Directory.current.path, 'migrations'));
    final localFiles = <String>[];
    if (migrationsDir.existsSync()) {
      for (final entity in migrationsDir.listSync()..sort((a, b) => a.path.compareTo(b.path))) {
        if (entity is File && entity.path.endsWith('.dart')) {
          localFiles.add(p.basename(entity.path));
        }
      }
    }

    // Fetch applied migrations from backend.
    Set<String> appliedTitles = {};
    try {
      final response = await http.post(
        Uri.parse('${config.server}/api/migration/listMigrations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          appliedTitles = data.map((e) => e.toString()).toSet();
        } else if (data is Map && data['migrations'] is List) {
          appliedTitles =
              (data['migrations'] as List).map((e) => e.toString()).toSet();
        }
      } else {
        stderr.writeln(
            'Warning: could not fetch applied migrations (${response.statusCode}). Showing local only.');
      }
    } catch (e) {
      stderr.writeln('Warning: could not reach server. Showing local only.');
    }

    if (localFiles.isEmpty) {
      stdout.writeln('No local migration files found in migrations/.');
      return;
    }

    stdout.writeln('Migrations:');
    for (final file in localFiles) {
      final isApplied = appliedTitles.any((t) => file.contains(t));
      final status = isApplied ? '[applied]' : '[pending]';
      stdout.writeln('  $status $file');
    }
  }
}

// ---------------------------------------------------------------------------
// run
// ---------------------------------------------------------------------------

class _RunSubcommand extends Command {
  @override
  String get name => 'run';

  @override
  String get description => 'Run a migration file against the backend';

  _RunSubcommand() {
    argParser
      ..addOption('token', help: 'API token for CI/CD')
      ..addFlag('dry-run',
          abbr: 'n',
          help: 'Preview changes without applying them',
          negatable: false);
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      stderr.writeln('Usage: dartdesk migration run <file>');
      exit(64);
    }

    final filePath = rest.first;
    final file = File(filePath);
    if (!file.existsSync()) {
      stderr.writeln('File not found: $filePath');
      exit(1);
    }

    final content = file.readAsStringSync();
    final migration = _parseMigrationFile(content);

    if (migration == null) {
      stderr.writeln(
          'Could not parse migration file. Ensure it uses defineMigration() with title and documentType.');
      exit(1);
    }

    final config = CmsConfig.load();
    final token = _resolveToken(argResults);
    final dryRun = argResults!['dry-run'] as bool;

    stdout.writeln(
        '${dryRun ? '[DRY RUN] ' : ''}Running migration: ${migration.title}');

    final response = await http.post(
      Uri.parse('${config.server}/api/migration/runMigration'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': migration.title,
        'documentType': migration.documentType,
        'operationsJson': migration.operationsToJson(),
        'dryRun': dryRun,
      }),
    );

    if (response.statusCode == 200) {
      stdout.writeln('Migration report:');
      stdout.writeln(response.body);
    } else {
      stderr.writeln('Migration failed (${response.statusCode}): ${response.body}');
      exit(1);
    }
  }

  /// Parse a migration Dart file using regex extraction.
  Migration? _parseMigrationFile(String content) {
    final titleMatch = RegExp(r"title:\s*'([^']*)'").firstMatch(content);
    final docTypeMatch =
        RegExp(r"documentType:\s*'([^']*)'").firstMatch(content);

    if (titleMatch == null || docTypeMatch == null) return null;

    final title = titleMatch.group(1)!;
    final documentType = docTypeMatch.group(1)!;
    final operations = <MigrationOp>[];

    // Parse renameField('from', 'to')
    for (final match
        in RegExp(r"renameField\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)")
            .allMatches(content)) {
      operations.add(renameField(match.group(1)!, match.group(2)!));
    }

    // Parse deleteField('path')
    for (final match
        in RegExp(r"deleteField\(\s*'([^']*)'\s*\)").allMatches(content)) {
      operations.add(deleteField(match.group(1)!));
    }

    // Parse setField('path', value)
    for (final match
        in RegExp(r"setField\(\s*'([^']*)'\s*,\s*(.+?)\s*\)")
            .allMatches(content)) {
      final path = match.group(1)!;
      final valueStr = match.group(2)!.trim();
      dynamic value;
      if (valueStr == 'true') {
        value = true;
      } else if (valueStr == 'false') {
        value = false;
      } else if (valueStr == 'null') {
        value = null;
      } else if (int.tryParse(valueStr) != null) {
        value = int.parse(valueStr);
      } else if (double.tryParse(valueStr) != null) {
        value = double.parse(valueStr);
      } else {
        value = valueStr.replaceAll(RegExp(r"^'|'$"), '');
      }
      operations.add(setField(path, value));
    }

    return defineMigration(
      title: title,
      documentType: documentType,
      operations: operations,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _resolveToken(argResults) {
  final tokenArg = argResults?['token'] as String?;
  if (tokenArg != null) return tokenArg;

  final creds = Credentials.load();
  if (creds == null) {
    stderr.writeln('Not authenticated. Run: dartdesk login');
    exit(1);
  }
  if (creds.isExpired) {
    stderr.writeln('Session expired. Run: dartdesk login');
    exit(1);
  }
  return creds.token;
}
