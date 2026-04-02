import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../config.dart';
import '../credentials.dart';

class DeployCommand extends Command {
  @override
  String get name => 'deploy';

  @override
  String get description => 'Build and deploy the Dart Desk studio to cloud';

  DeployCommand() {
    argParser
      ..addOption('token',
          help: 'API token for CI/CD (skips saved credentials)')
      ..addFlag('skip-build',
          help: 'Skip flutter build web, upload existing build/',
          negatable: false)
      ..addOption('commit',
          help: 'Git commit hash to associate with deployment');
  }

  @override
  Future<void> run() async {
    final config = CmsConfig.load();
    final token = _resolveToken();

    if (argResults!['skip-build'] != true) {
      stdout.writeln('Building Flutter web app...');
      final buildResult = await Process.run(
        'flutter',
        ['build', 'web', '--release'],
        workingDirectory: Directory.current.path,
      );
      if (buildResult.exitCode != 0) {
        stderr.writeln('Build failed:\n${buildResult.stderr}');
        exit(1);
      }
      stdout.writeln('Build complete.');
    }

    final buildDir = Directory(p.join(Directory.current.path, 'build', 'web'));
    if (!buildDir.existsSync()) {
      stderr.writeln('build/web/ not found. Run flutter build web first.');
      exit(1);
    }

    stdout.writeln('Packaging build output...');
    final tarGzBytes = _createTarGz(buildDir);
    final sizeMB = (tarGzBytes.length / (1024 * 1024)).toStringAsFixed(1);
    stdout.writeln('Package size: ${sizeMB}MB');

    if (tarGzBytes.length > 100 * 1024 * 1024) {
      stderr.writeln('Error: Package exceeds 100MB limit.');
      exit(1);
    }

    stdout.writeln('Deploying ${config.projectId}...');
    final url =
        Uri.parse('${config.server}/deployment/upload?slug=${config.projectId}');

    final request = http.Request('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'application/gzip'
      ..bodyBytes = tarGzBytes;

    final response = await http.Client().send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      stderr.writeln('Deploy failed (${response.statusCode}): $responseBody');
      exit(1);
    }

    final result = jsonDecode(responseBody) as Map<String, dynamic>;
    stdout.writeln('');
    stdout.writeln('Deployed v${result['version']} -> ${result['url']}');
  }

  String _resolveToken() {
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

  List<int> _createTarGz(Directory buildDir) {
    final archive = Archive();
    final basePath = buildDir.path;

    for (final entity in buildDir.listSync(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: basePath);
        final bytes = entity.readAsBytesSync();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    final tarBytes = TarEncoder().encode(archive);
    return GZipEncoder().encode(tarBytes);
  }
}
