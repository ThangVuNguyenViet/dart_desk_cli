import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

class CmsConfig {
  static const defaultServer = 'https://api.dartdesk.dev';

  final String clientSlug;
  final String projectSlug;
  final String server;

  CmsConfig({
    required this.clientSlug,
    required this.projectSlug,
    required this.server,
  });

  static CmsConfig load([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final file = File(p.join(dir, 'dart_desk.yaml'));

    if (!file.existsSync()) {
      throw Exception(
        'dart_desk.yaml not found in $dir\n'
        'Create one with:\n'
        '  client_slug: <your client slug>\n'
        '  project_slug: <your project slug>',
      );
    }

    final yaml = loadYaml(file.readAsStringSync()) as YamlMap;

    if (yaml.containsKey('project_id')) {
      throw Exception(
        'dart_desk.yaml uses the legacy `project_id` field. Replace it with:\n'
        '  client_slug: <your client slug>\n'
        '  project_slug: <your project slug>',
      );
    }

    final clientSlug = yaml['client_slug'] as String?;
    final projectSlug = yaml['project_slug'] as String?;
    if (clientSlug == null || clientSlug.isEmpty ||
        projectSlug == null || projectSlug.isEmpty) {
      throw Exception(
        'dart_desk.yaml must contain `client_slug` and `project_slug` strings',
      );
    }

    final server = (yaml['server'] as String?) ?? defaultServer;
    return CmsConfig(
      clientSlug: clientSlug,
      projectSlug: projectSlug,
      server: server.replaceAll(RegExp(r'/$'), ''),
    );
  }
}
