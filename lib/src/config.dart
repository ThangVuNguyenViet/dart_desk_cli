import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

class CmsConfig {
  final String projectSlug;
  final String server;

  CmsConfig({required this.projectSlug, required this.server});

  static CmsConfig load([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final file = File(p.join(dir, 'dart_desk.yaml'));

    if (!file.existsSync()) {
      throw Exception(
        'dart_desk.yaml not found in $dir\n'
        'Create one with:\n'
        '  project_slug: your-project-slug\n'
        '  server: https://api.dartdesk.dev',
      );
    }

    final yaml = loadYaml(file.readAsStringSync()) as YamlMap;
    final projectSlug = yaml['project_slug'] as String?;
    if (projectSlug == null || projectSlug.isEmpty) {
      throw Exception('dart_desk.yaml must contain a "project_slug" field');
    }

    final server = (yaml['server'] as String?) ?? 'https://api.dartdesk.dev';
    return CmsConfig(projectSlug: projectSlug, server: server.replaceAll(RegExp(r'/$'), ''));
  }
}
