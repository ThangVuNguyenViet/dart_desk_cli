import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

class CmsConfig {
  final String slug;
  final String server;

  CmsConfig({required this.slug, required this.server});

  static CmsConfig load([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final file = File(p.join(dir, 'dart_desk.yaml'));

    if (!file.existsSync()) {
      throw Exception(
        'dart_desk.yaml not found in $dir\n'
        'Create one with:\n'
        '  slug: your-project-slug\n'
        '  server: https://api.dartdesk.dev',
      );
    }

    final yaml = loadYaml(file.readAsStringSync()) as YamlMap;
    final slug = yaml['slug'] as String?;
    if (slug == null || slug.isEmpty) {
      throw Exception('dart_desk.yaml must contain a "slug" field');
    }

    final server = (yaml['server'] as String?) ?? 'https://api.dartdesk.dev';
    return CmsConfig(slug: slug, server: server.replaceAll(RegExp(r'/$'), ''));
  }
}
