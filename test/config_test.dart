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

    test('parses the new shape', () {
      File(p.join(tempDir.path, 'dart_desk.yaml')).writeAsStringSync('''
client_slug: dartdesk
project_slug: demo
server: https://api.dartdesk.dev
''');
      final config = CmsConfig.load(tempDir.path);
      expect(config.clientSlug, equals('dartdesk'));
      expect(config.projectSlug, equals('demo'));
      expect(config.server, equals('https://api.dartdesk.dev'));
    });

    test('errors with helpful message on legacy project_id field', () {
      File(p.join(tempDir.path, 'dart_desk.yaml')).writeAsStringSync('''
project_id: dartdesk-demo
server: https://api.dartdesk.dev
''');
      expect(
        () => CmsConfig.load(tempDir.path),
        throwsA(predicate((e) =>
            e.toString().contains('project_id') &&
            e.toString().contains('client_slug'))),
      );
    });

    test('errors when client_slug or project_slug missing', () {
      File(p.join(tempDir.path, 'dart_desk.yaml')).writeAsStringSync('''
client_slug: dartdesk
server: https://api.dartdesk.dev
''');
      expect(() => CmsConfig.load(tempDir.path), throwsA(isA<Exception>()));
    });

    test('defaults server when not specified', () {
      File(p.join(tempDir.path, 'dart_desk.yaml')).writeAsStringSync('''
client_slug: dartdesk
project_slug: demo
''');
      final config = CmsConfig.load(tempDir.path);
      expect(config.server, 'https://api.dartdesk.dev');
    });

    test('throws when file missing', () {
      expect(() => CmsConfig.load(tempDir.path), throwsException);
    });
  });
}
