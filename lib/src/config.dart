import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

class CmsConfig {
  static const defaultServer = 'https://api.dartdesk.dev';

  final String projectId;
  final String server;

  CmsConfig({required this.projectId, required this.server});

  static CmsConfig load([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final file = File(p.join(dir, 'dart_desk.yaml'));

    if (!file.existsSync()) {
      throw Exception(
        'dart_desk.yaml not found in $dir\n'
        'Create one with:\n'
        '  project_id: your-project-id',
      );
    }

    final yaml = loadYaml(file.readAsStringSync()) as YamlMap;
    final projectId = yaml['project_id'] as String?;
    if (projectId == null || projectId.isEmpty) {
      throw Exception('dart_desk.yaml must contain a "project_id" field');
    }

    final server = (yaml['server'] as String?) ?? defaultServer;
    return CmsConfig(projectId: projectId, server: server.replaceAll(RegExp(r'/$'), ''));
  }
}
