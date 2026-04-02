import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../config.dart';
import '../credentials.dart';

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
    file.writeAsStringSync(_migrationTemplate(title, slug));

    stdout.writeln('Created migration: migrations/$fileName');
  }

  String _migrationTemplate(String title, String slug) {
    return '''// Migration: $title
// Generated: ${DateTime.now().toIso8601String()}

const String migrationTitle = '$title';
const String migrationDocumentType = 'yourDocumentType';

const List<Map<String, dynamic>> operations = [
  // Example operation:
  // {
  //   'type': 'addField',
  //   'field': 'fieldName',
  //   'value': null,
  // },
];
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
          'Could not parse migration file. Ensure it defines migrationTitle, migrationDocumentType, and operations.');
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

  _MigrationDef? _parseMigrationFile(String content) {
    final titleMatch =
        RegExp(r"const\s+String\s+migrationTitle\s*=\s*'([^']*)'").firstMatch(content) ??
        RegExp(r'const\s+String\s+migrationTitle\s*=\s*"([^"]*)"').firstMatch(content);
    final docTypeMatch =
        RegExp(r"const\s+String\s+migrationDocumentType\s*=\s*'([^']*)'").firstMatch(content) ??
        RegExp(r'const\s+String\s+migrationDocumentType\s*=\s*"([^"]*)"').firstMatch(content);
    final opsMatch = RegExp(
            r'const\s+List<Map<String,\s*dynamic>>\s+operations\s*=\s*(\[[\s\S]*?\]);',
            multiLine: true)
        .firstMatch(content);

    if (titleMatch == null || docTypeMatch == null) return null;

    final title = titleMatch.group(1)!;
    final documentType = docTypeMatch.group(1)!;
    final operationsRaw = opsMatch?.group(1) ?? '[]';

    return _MigrationDef(
      title: title,
      documentType: documentType,
      operationsRaw: operationsRaw,
    );
  }
}

class _MigrationDef {
  final String title;
  final String documentType;
  final String operationsRaw;

  _MigrationDef({
    required this.title,
    required this.documentType,
    required this.operationsRaw,
  });

  /// Returns the operations as a JSON string suitable for the backend.
  /// Because the Dart literal may not be valid JSON, we pass it as-is as a
  /// raw string and let the backend parse it.  For simple cases (no Dart-only
  /// syntax) this works.  A future improvement would be to evaluate the file.
  String operationsToJson() => operationsRaw;
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
