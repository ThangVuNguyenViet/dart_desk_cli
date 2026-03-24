import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../credentials.dart';

class DeploymentsCommand extends Command {
  @override
  String get name => 'deployments';

  @override
  String get description => 'Manage deployments';

  DeploymentsCommand() {
    addSubcommand(_ListSubcommand());
    addSubcommand(_RollbackSubcommand());
  }
}

class _ListSubcommand extends Command {
  @override
  String get name => 'list';

  @override
  String get description => 'List deployment history';

  _ListSubcommand() {
    argParser.addOption('token', help: 'API token for CI/CD');
  }

  @override
  Future<void> run() async {
    final config = CmsConfig.load();
    final token = _resolveToken(argResults);

    final response = await http.get(
      Uri.parse('${config.server}/deployment?slug=${config.projectSlug}&action=list'),
      headers: {'Authorization': 'Bearer $token'},
    );

    stdout.writeln('Deployments for ${config.projectSlug}:');
    stdout.writeln(response.body);
  }
}

class _RollbackSubcommand extends Command {
  @override
  String get name => 'rollback';

  @override
  String get description => 'Activate a previous deployment version';

  _RollbackSubcommand() {
    argParser
      ..addOption('token', help: 'API token for CI/CD')
      ..addOption('version', abbr: 'v', help: 'Version to activate', mandatory: true);
  }

  @override
  Future<void> run() async {
    final config = CmsConfig.load();
    final token = _resolveToken(argResults);
    final version = int.parse(argResults!['version']);

    final response = await http.post(
      Uri.parse('${config.server}/deployment?slug=${config.projectSlug}&action=activate&version=$version'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      stdout.writeln('Activated v$version for ${config.projectSlug}');
    } else {
      stderr.writeln('Rollback failed: ${response.body}');
      exit(1);
    }
  }
}

String _resolveToken(argResults) {
  final tokenArg = argResults?['token'] as String?;
  if (tokenArg != null) return tokenArg;

  final creds = Credentials.load();
  if (creds == null) {
    stderr.writeln('Not authenticated. Run: dart_desk login');
    exit(1);
  }
  if (creds.isExpired) {
    stderr.writeln('Session expired. Run: dart_desk login');
    exit(1);
  }
  return creds.token;
}
