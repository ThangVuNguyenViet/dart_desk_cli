import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:dart_desk_cli/src/config.dart';

void main() {
  group('CmsConfig', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cms_config_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('loads project_id and server from yaml', () {
      File(p.join(tempDir.path, 'dart_desk.yaml')).writeAsStringSync('project_id: my-project\nserver: https://custom.server.com\n');
      final config = CmsConfig.load(tempDir.path);
      expect(config.projectId, 'my-project');
      expect(config.server, 'https://custom.server.com');
    });

    test('defaults server when not specified', () {
      File(p.join(tempDir.path, 'dart_desk.yaml')).writeAsStringSync('project_id: my-project\n');
      final config = CmsConfig.load(tempDir.path);
      expect(config.server, 'https://api.dartdesk.dev');
    });

    test('throws when file missing', () {
      expect(() => CmsConfig.load(tempDir.path), throwsException);
    });

    test('throws when project_id missing', () {
      File(p.join(tempDir.path, 'dart_desk.yaml')).writeAsStringSync('server: https://example.com\n');
      expect(() => CmsConfig.load(tempDir.path), throwsException);
    });
  });
}
